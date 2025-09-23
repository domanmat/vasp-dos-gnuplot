
#idea - podać 4 argumenty: x_min, x_max, y_min, y_max
#jeśli ich nie ma, dać defaulty

#README - opcje wykorzystania
# 1) dosplot-spin.sh -4 4 --> wyrysowanie total dos_up i _down w górę i w dół
# 2) dosplot-spin.sh -4 4 redraw --> wyrysowanie DOS na bazie poprzednich danych
# 3) dosplot-spin.sh -4 4 atoms 1 2 3 4 12   --> wyrysowanie DOS-ów projektowanych dla atomów 1,2,3,4,12 (oddzielnie)
# 4) dosplot-spin.sh -4 4 atoms 1-4 12   --> wyrysowanie DOS-ów projektowanych dla atomów 1-4 (razem) ,12 (oddzielnie)
#
#

# bashowe polecenia
# 1) do wyrysowania z listy
# for i in $list; do dir=$(pwd); cd $i ;  dosplot-spin.sh -4 4 redraw ; cd $dir; echo $i; done
# 2) do skopiowania do local_dir
# for i in $list; do dir=$(pwd); cd $i ;  cp dos_tot_pdos_all.png ../$i-dos_tot_pdos_all.png ; cd $dir; echo $i; done

echo
echo '!Necessary options are: x_min x_max {Modes}'
echo '!Additional options are: x_min x_max {Styles} {Modes}'
echo '!{Styles} are: YLIM y_min y_max ; dos=mode(not yet) ; stack(not yet) '
echo '!{Modes} are: redraw (no options)'
echo '!             atoms (e.g. "1 2 3" or "1-3" or "default")'
echo '!             orbitals (e.g. "1dxy 2s 3all" or "1-2all 3-4dxy")'
echo


####usuwanie komend gnuplot'a
rm -f plotfile*
#rm -f dos_tmp 

curdir=$(pwd)
curdir=$(echo $curdir | rev | cut -d '/' -f 1 | rev )
if [ -d "./gnu-tmp-$curdir" ] ; then 
 mv "./gnu-tmp-$curdir" "./gnu_tmp-$curdir"
else
 mkdir -p "./gnu_tmp-$curdir"
fi 

if [ -d ./gnu-tmp-* ] ; then 
  rm -r ./gnu-tmp-*
fi
mv  "./gnu_tmp-$curdir" "./gnu-tmp-$curdir"
dir="./gnu-tmp-$curdir"



arguments=`echo $@`
echo $arguments

#sprawdza czy liczba argumentów to zero
if [ $# -gt 0 ];   then
  x_min=$1
  x_max=$2
else
  #unset y_min y_max
  x_min=-10
  x_max=10
fi
echo 'x_min='$x_min
echo 'x_max='$x_max

#sprawdza czy są orbitale f-orbitals
if grep -q 'fxyz' vasprun.xml ; then
  echo '!Possible orbitals are: s  py  pz  px  dxy  dyz  dz2  dxz  fy3x2  fxyz  fyz2  fz3  fxz2  fzx2  fx3  all'
 orbital_list='s py pz px dxy dyz dz2 dxz fy3x2 fxyz fyz2 fz3 fxz2 fzx2 fx3 all' #16 orbitali + all
 orbital_numbers='1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17'
 max_column=18
   columns='3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18'
	 
elif grep -q 'dxy' vasprun.xml ; then
  echo '!Possible orbitals are: s   py   pz   px  dxy  dyz  dz2  dxz  x2-y2'
 orbital_list='s py pz px dxy dyz dz2 dxz x2-y2 all' #9 orbitali + all
 orbital_numbers='1 2 3 4 5 6 7 8 9 10'
 max_column=11
   columns='3 4 5 6 7 8 9 10 11'
	 
fi

#wartości maksymalne i minimalne ylim
#for i in $arguments; do
if echo "$@" | grep -iq 'ylim' ; then
    #printuje argumenty, rozdziela po ylim, daje pierwszy argument za ylim, a potem drugi
    y_min=$(echo $@ | awk -F "ylim" '{print $2}' |  awk  '{print $1}')
    y_max=$(echo $@ | awk -F "ylim" '{print $2}' |  awk  '{print $2}')
	 echo 'y_min='$y_min 
	 echo 'y_max='$y_max
else
    unset y_min y_max
fi


#REDRAW ALL THE DATA mode
if [[ $@ == *"draw"* ]] ; then
echo '!Redrawing prepared data'
mode='redraw'

else 


signature_new=$(echo *.out | rev | cut -d- -f1 | rev | cut -d. -f1)
signature_old=$(echo xsignature-* | rev | cut -d- -f1 | rev | cut -d. -f1)
if [[ $signature_new == *"$signature_old"* ]] ; then
 #echo 1
 echo "$signature_new" > xsignature-$signature_new
 echo "!Re-using previously prepared DOS data"
else 
 #echo 2
 rm -f signature-*
 echo "$signature_new" > xsignature-$signature_new
 echo "!Preparing new DOS data"
fi 
#mv signature-$signature_new $dir



#struktura vasprun.xml:
# czyta parametry incara
# na koniec - struktura pasmowa dla każdego k-punktu po kolei z podziałem na spin1 i spin2
n_atoms=`awk '/<atoms>/ {print $2}' vasprun.xml`
n_types=`awk '/<types>/ {print $2}' vasprun.xml`
nedos=`awk '/NEDOS/ {print $6}'  OUTCAR`
echo 'number of atoms = '$n_atoms
echo 'atomic types = '$n_types


#wycina DOS_tot spin_up i spin_down
awk '
     BEGIN{i=1}/<total>/{flag=1;next}/<\/total>/{flag=0}flag{
	 a[i]=$2 ; b[i]=$3 ; i=i+1}
	 END{for(j=8;j<i-3;j++) 
	 print a[j],b[j]
	 }' vasprun.xml > $dir/dos_all.dat 

#definition of a real number $re
re='^[0-9]+$'

#sed -n "/atomtype/,/atomtypes/p" vasprun.xml | head -n -3 | sed '1,2d' | cut -c 12-13 >> atomtypes
rm -f $dir/atomtypes
rm -f $dir/atomtypes_list
rm -f $dir/atom*pDOS
rm -f atom*
rm -f plotfile*
rm -f temp*
rm -f gr*atoms*type*
rm -f $dir/temp*
rm -f $dir/temp*
rm -f dos-*
rm -f gr-up*atoms*type*
rm -f gr-dn*atoms*type*
sed -n "/atomtype/,/atomtypes/p" vasprun.xml | head -n -3 | sed '1,2d' | cut -c 12-13 | awk '{print $1}' > $dir/atomtypes
sed -n "/atomtype/,/atomtypes/p" vasprun.xml | head -n -3 | sed '1,2d' | cut -c 22-24 | awk '{print $1}' > $dir/atomgroup

############################ część identyfikująca układ i robiąca domyślną at_list
#a - liczy atomy
#b - liczy atomy w grupach
#c - zapamiętuje pierwszy atom z grupy
#d - zapamiętuje ostatni atom z grupy
a=0
b=0
c=1
d=0 
unset arr_no
unset arr_typ
declare -a arr_no
declare -a arr_typ
atomtypes=$(cat $dir/atomtypes)
unset prev_at
for at in $atomtypes; do
 a=$((a+1))
 if [[ "$at" == "$prev_at" ]] || [ -z "$prev_at" ] ; then #
  b=$((b+1))
 elif [[ "$at" != "$prev_at" ]] ; then
  d=$((a-1))
  #e=$((c+b-1))
  #echo $c-$d
  arr_no+=("$c-$d")
  arr_typ+=("$prev_at")
  #echo $c-$e
  c=$a
  b=1
 fi
 #echo $at $prev_at $a $b $c
 prev_at=$at
 if [[ "$a" == "$n_atoms" ]] ; then
  d=$((a))
  #echo $c-$d
  arr_no+=("$c-$d")
  arr_typ+=("$prev_at")
 fi
done
echo '!All atomic types are: '${arr_typ[@]}
echo '!Corresponding groups are: '${arr_no[@]}
#echo ${arr_no[@]}
############################ część identyfikująca układ i robiąca domyślną at_list
 
# !!! przed 'atoms' lub 'orbitals' da się wsadzić coś jeszcze, np. Y-limit, mode 'are stacked chart', lub 'no total dos'

#mode: ATOMS
if echo "$@" | grep -iq 'atom'; then
mode='atoms'

#for i in $@; do
# if echo "$i" | grep -iq 'atom' ; then
#     #printuje argumenty, rozdziela po ylim, daje pierwszy argument za ylim, a potem drugi
#     y_min=$(echo $@ | awk -F "$i" '{print $2}' |  awk  '{print $1}')
#     y_max=$(echo $@ | awk -F "$i" '{print $2}' |  awk  '{print $2}')
#	 echo 'y_min='$y_min 
#	 echo 'y_max='$y_max
# else
#     unset y_min y_max
# fi
#done

##ZBĘDNE
##first atom argument
#a=$4
##last atom argument
#b=${@: -1}
##czyta pierwszy i ostatni atom



##printuje wszystkie argumenty
#echo $@ 
#echo $@ | awk -F 'atoms' '{print $2}'
at_list=`echo $@ | awk -F 'atoms' '{print $2}'`

if echo $at_list | grep -q 'def' || echo $at_list | grep -q 'all' ; then
  echo '!Default plotting mode for atoms'
  at_list=$(echo ${arr_no[@]})
fi
  

echo "!Plotting for atoms: "$at_list
#if echo $at_list | grep -q '-' ; then
#	 echo
#fi
#if echo $@ | grep -q 'atoms' ; then
 
 if [ $# -gt 3 ];   then
 rm -f $dir/dos-at*   
   #Zmienna 'x' numeruje grupy atomów podane w @arguments
   x=0
   
   for at in $at_list; do
    x=$((x+1))
    i=$at
    #echo $i
	
	#if  [ $at -gt $n_atoms ]; then
	#  echo 'atoms are ' $at 'while there are ' $n_atoms ' atoms'
	#  echo '!!!too much atoms!!!'
	#  break
	#fi
	
	#jeśli podano zakres atomów np. 2-5
    if echo $at | grep -q '-' ; then
	 #k=$at
     first=$(echo $at | cut -d '-' -f1)
     last=$(echo $at | cut -d '-' -f2)
	 
	 atomtype=$(sed -n "$first p" $dir/atomtypes ) #daje H, Ca, itp o takim indeksie jak tu
	 echo $atomtype >> $dir/atomtypes_list
	 last_type=$(sed -n "$last p" $dir/atomtypes )
	 if ! [[ "$atomtype" == "$last_type" ]]; then
	     echo 'ERROR atomic types of atoms are not consistent!'
     fi
	 
	 #echo $atomtype 
	 
	 #echo $first $last
	 #at_g to kolejne liczby ze stringu 'atom' czyli grupy, mogą być np. 5-7 to i będzie 5, 6 i 7
	 for (( at_g=$first; at_g<=$last; at_g++ )); do
	   j=$((at_g+1))
	   atomtype=$(sed -n "$at_g p" $dir/atomtypes )
	   echo 'atom '$at_g $atomtype
       #echo 'atom '$at_g $j
	   #wycina plik od atomu i do atomu i+1 (CO GDY NIE MA JUŻ ATOMU i+1 ? )
	   if [[ $at_g = $n_atoms ]] ; then
	    sed -n "/ion $at_g\"/, /dos/p" vasprun.xml | head -n -3  > $dir/dos-at$at_g
	   else
	    sed -n "/ion $at_g\"/, /ion $j\"/p" vasprun.xml > $dir/dos-at$at_g	 
	   fi	 
	   #wycina 1-szą linię i usuwa ostatnie 2
	   sed -n '/spin 1/,/spin 2/p' $dir/dos-at$at_g | sed '1d' | head -n -2 > $dir/dos-at$at_g-up
	   #wycina 1-szą linię i usuwa ostatnie 3
	   sed -n '/spin 2/,$p' $dir/dos-at$at_g | sed '1d'| head -n -3 > $dir/dos-at$at_g-down
	   #dodaje kolumny w rzędzie od 3 do $max_column (18 lub 11) co 1 jako "sum"; drukuje $2 i tę "sum" i drukuje to do pliku
	   awk -v max=$max_column '{sum=0;for(i=3;i<=max;++i){sum+=$i}; print $2, sum}' $dir/dos-at$at_g-up > $dir/dos-at$at_g-up-sum
	   awk -v max=$max_column '{sum=0;for(i=3;i<=max;++i){sum+=$i}; print $2, sum}' $dir/dos-at$at_g-down > $dir/dos-at$at_g-down-sum
	   
	   #if grep -q 'fxyz' vasprun.xml ; then
	   #  awk '{sum=0;for(i=3;i<=18;++i){sum+=$i}; print $2, sum}' $dir/dos-at$at_g-up > $dir/dos-at$at_g-up-sum
	   #  awk '{sum=0;for(i=3;i<=18;++i){sum+=$i}; print $2, sum}' $dir/dos-at$at_g-down > $dir/dos-at$at_g-down-sum
	   #elif grep -q 'dxy' vasprun.xml ; then
	   #  awk '{sum=0;for(i=3;i<=11;++i){sum+=$i}; print $2, sum}' $dir/dos-at$at_g-up > $dir/dos-at$at_g-up-sum
	   #  awk '{sum=0;for(i=3;i<=11;++i){sum+=$i}; print $2, sum}' $dir/dos-at$at_g-down > $dir/dos-at$at_g-down-sum
	   #else 
	   # echo 'orbital problem - ERROR' 
	   # break
	   #fi
	   
	   #sumowanie dla wielu atomów
	   #ważne rozróżnienie, gdy mamy atoms 1-4 to at_g to po kolei 1,2,3,4 ale at=1-4
	   if [[ $at_g = $first ]] ; then
	     cp    $dir/dos-at$first-up-sum       $dir/dos-at$at-up-sum
	     cp    $dir/dos-at$first-down-sum     $dir/dos-at$at-down-sum
	     rm -f $dir/dos-at$at_g-up-sum        $dir/dos-at$at_g-down-sum
	    else
	     cp $dir/dos-at$at-up-sum   TEMP1
	     cp $dir/dos-at$at-down-sum TEMP2
	     awk 'FNR==NR { a[FNR]=$2;} NR!=FNR { $2 += a[FNR]; print;  }' $dir/dos-at$at_g-up-sum TEMP1 >   $dir/dos-at$at-up-sum
	     awk 'FNR==NR { a[FNR]=$2;} NR!=FNR { $2 += a[FNR]; print;  }' $dir/dos-at$at_g-down-sum TEMP2 > $dir/dos-at$at-down-sum
	     rm -f TEMP1 TEMP2
	     rm -f $dir/dos-at$at_g-up-sum $dir/dos-at$at_g-down-sum
	   fi
	 done
	
	#jeśli podano tylko jeden atom np. 1 2 3 4 
    elif [[ $at =~ $re ]] ; then
	 
	 atomtype=$(sed -n "$at p" $dir/atomtypes) #daje H, Ca, itp o takim indeksie jak tu
	 echo $atomtype >> $dir/atomtypes_list
	 #echo $atomtype 
	 
	 j=$((at+1))
	 echo 'atom '$at $atomtype
     #echo 'atom '$i $j
	 #wycina plik od atomu i do atomu i+1 (CO GDY NIE MA JUŻ ATOMU i+1 ? )
	 if [[ $at = $n_atoms ]] ; then
	  sed -n "/ion $at\"/, /dos/p" vasprun.xml | head -n -3  > $dir/dos-at$at
	 else
	  sed -n "/ion $at\"/, /ion $j\"/p" vasprun.xml > $dir/dos-at$at	 
	 fi	 
	  
	 #wycina 1-szą linię i usuwa ostatnie 2
	 sed -n '/spin 1/,/spin 2/p' $dir/dos-at$at | sed '1d' | head -n -2 > $dir/dos-at$at-up
	 #wycina 1-szą linię i usuwa ostatnie 3
	 sed -n '/spin 2/,$p' $dir/dos-at$at | sed '1d'| head -n -3 > $dir/dos-at$at-down
	 #dodaje kolumny w rzędzie od 3 do 11 co 1 jako "sum"; drukuje $2 i tę "sum" i drukuje to do pliku
	 awk -v max=$max_column '{sum=0;for(i=3;i<=max;++i){sum+=$i}; print $2, sum}' $dir/dos-at$at-up >   $dir/dos-at$at-up-sum
	 awk -v max=$max_column '{sum=0;for(i=3;i<=max;++i){sum+=$i}; print $2, sum}' $dir/dos-at$at-down > $dir/dos-at$at-down-sum
	 
	 #integrated nth atom DOS
	 #awk '{sum=0;for(i=3;i<=11;++i){c+=$i}; print $2, c}' dos-at$i-down > dos-at$i-down-int
	 
	 #awk '{sum=0;for(i=3;i<=11;++i){c+=$i}; print $2, c}' dos-at$i > dos-sum-at$i
	 #awk '{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i, a[i], b[i]|"sort"}' dos-at$i > dos-sum-at$i
	
	else 
	 echo 'Provided atom is not a number'
    fi
	
   echo $at $atomtype
   #x - is a number of each atom
   cp $dir/dos-at$at-up-sum     gr-up$x-atoms-$at-type-$atomtype
   cp $dir/dos-at$at-down-sum   gr-dn$x-atoms-$at-type-$atomtype
   
   done
 fi
fi


#mode: ORBITALS
if [[ "$@" == *"orbital"* ]]; then
mode='orbitals'

#ORBITALS new part START
##printuje wszystkie argumenty
at_list=`echo $@ | awk -F 'orbitals' '{print $2}'`
echo $at_list

#CZY SĄ ORBITALE f-orbitals
if grep -q 'fxyz' vasprun.xml ; then
  #echo 'Possible orbitals are: s  py  pz  px  dxy  dyz  dz2  dxz  fy3x2  fxyz  fyz2  fz3  fxz2  fzx2  fx3  all'
    orbital_list='s py pz px dxy dyz dz2 dxz fy3x2 fxyz fyz2 fz3 fxz2 fzx2 fx3 all' #16 orbitali + all
 orbital_numbers='1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17'

elif grep -q 'dxy' vasprun.xml ; then
  #echo 'Possible orbitals are: s   py   pz   px  dxy  dyz  dz2  dxz  x2-y2'
    orbital_list='s py pz px dxy dyz dz2 dxz x2-y2 all' #9 orbitali + all
 orbital_numbers='1 2 3 4 5 6 7 8 9 10'
         columns='3 4 5 6 7 8 9 10 11 12'
fi
#ORBITALS new part  END

 if [ $# -gt 3 ];   then
 rm -f $dir/dos-at*   
   #Zmienna 'x' numeruje grupy atomów podane w @arguments
   x=0
   for at in $at_list; do
    x=$((x+1))
    #i=$at
    #echo $i
	
	#ORBITALS new part START
	#for i in $string; do if [[ $string2 == *"$i"* ]]; then echo 'its there' ; fi; done
	for i in $orbital_numbers; do 
	 j=$(echo $orbital_list | cut -d ' ' -f $i)
	 if [[ $at == *"$j"* ]]; then 
	  echo 'its there' 
	  tmp=$(echo "$at" | sed -e "s/$j$//")
	  at=$tmp
	  #one per atom only! #	  echo $j
	  at_orbital=$j
	  orbital_number=$i
	  orbital_column=$((i+2))
	  echo 'atoms '$at 'orbitals ' $at_orbital 'number ' $orbital_number 'column ' $orbital_column
	 fi
    done
	#ORBITALS new part END
	
	#if  [ $at -gt $n_atoms ]; then
	#  echo 'atoms are ' $at 'while there are ' $n_atoms ' atoms'
	#  echo '!!!too much atoms!!!'
	#  break
	#fi
	
    if echo $at | grep -q '-' ; then
	 k=$at
     first=$(echo $at | cut -d '-' -f1)
     last=$(echo $at | cut -d '-' -f2)
	 atomtype=$(sed -n "$first p" $dir/atomtypes ) #daje H, Ca, itp o takim indeksie jak tu
	 last_type=$(sed -n "$last p" $dir/atomtypes )
	 if ! [[ "$atomtype" == "$last_type" ]]; then
	     echo 'ERROR atomic types of atoms are not consistent!'
     fi
	 
	 #atomtype=$(sed -n "$first p" atomtypes ) #daje H, Ca, itp o takim indeksie jak tu
	 #echo $atomtype' '$at_orbital >> atomtypes_list
	 #echo $atomtype 
	 
	 #echo $first $last
	 #i to kolejne liczby ze stringu 'atom' czyli mogą być np. 5-7 to i będzie 5, 6 i 7
	 for (( at_g=$first; at_g<=$last; at_g++ )); do
	   echo 0
	   j=$((at_g+1))
	   atomtype=$(sed -n "$at_g p" $dir/atomtypes )
	   echo 'atom '$at_g $atomtype $at_orbital
       #echo 'atom '$at_g $j
	   #wycina plik od atomu i do atomu i+1 (CO GDY NIE MA JUŻ ATOMU i+1 ? )
	   if [[ $at_g = $n_atoms ]] ; then
	    sed -n "/ion $at_g\"/, /dos/p" vasprun.xml | head -n -3  > $dir/dos-at$at_g
	   else
	    sed -n "/ion $at_g\"/, /ion $j\"/p" vasprun.xml >          $dir/dos-at$at_g	 
	   fi	 
	   #wycina 1-szą linię i usuwa ostatnie 2
	   sed -n '/spin 1/,/spin 2/p' $dir/dos-at$at_g | sed '1d' | head -n -2 > $dir/dos-at$at_g-up
	   #wycina 1-szą linię i usuwa ostatnie 3
	   sed -n '/spin 2/,$p' $dir/dos-at$at_g | sed '1d'| head -n -3 > $dir/dos-at$at_g-down
	   
	   #ORBITALS new part START
	   ##dodaje kolumny w rzędzie od 3 do 11 co 1 jako "sum"; drukuje $2 i tę "sum" i drukuje to do pliku
	   if [[ "$at_orbital" == *"al"* ]]; then
	    echo 1
	    awk -v max=$max_column '{sum=0;for(i=3;i<=max;++i){sum+=$i}; print $2, sum}' $dir/dos-at$at_g-up   > $dir/dos-at$at_g-orb-$at_orbital-up-sum
	    awk -v max=$max_column '{sum=0;for(i=3;i<=max;++i){sum+=$i}; print $2, sum}' $dir/dos-at$at_g-down > $dir/dos-at$at_g-orb-$at_orbital-down-sum
	   else
	   #dodaje kolumny w rzędzie od 3 do 11 co 1 jako "sum"; drukuje $2 i tę "sum" i drukuje to do pliku
	    echo 2
	    awk -v z=$orbital_column '{print $2, $z}'               $dir/dos-at$at_g-up   > $dir/dos-at$at_g-orb-$at_orbital-up-sum
	    awk -v z=$orbital_column '{print $2, $z}'               $dir/dos-at$at_g-down > $dir/dos-at$at_g-orb-$at_orbital-down-sum
	   fi
	   
	   #sumowanie dla wielu atomów gdy mamy np. 5-7
	   if [[ $at_g = $first ]] ; then
	     cp    $dir/dos-at$first-orb-$at_orbital-up-sum   $dir/dos-at$at-orb-$at_orbital-up-sum
	     cp    $dir/dos-at$first-orb-$at_orbital-down-sum $dir/dos-at$at-orb-$at_orbital-down-sum
	     rm -f $dir/dos-at$at_g-orb-$at_orbital-up-sum    $dir/dos-at$at_g-orb-$at_orbital-down-sum
	   else
	     cp $dir/dos-at$at-orb-$at_orbital-up-sum   TEMP1
	     cp $dir/dos-at$at-orb-$at_orbital-down-sum TEMP2
		 echo 3
	     awk 'FNR==NR { a[FNR]=$2;} NR!=FNR { $2 += a[FNR]; print;  }' $dir/dos-at$at_g-orb-$at_orbital-up-sum   TEMP1 > $dir/dos-at$at-orb-$at_orbital-up-sum
	     awk 'FNR==NR { a[FNR]=$2;} NR!=FNR { $2 += a[FNR]; print;  }' $dir/dos-at$at_g-orb-$at_orbital-down-sum TEMP2 > $dir/dos-at$at-orb-$at_orbital-down-sum
	     rm -f TEMP1 TEMP2
	     rm -f $dir/dos-at$at_g-orb-$at_orbital-up-sum 
		 rm -f $dir/dos-at$at_g-orb-$at_orbital-down-sum
	   fi
	   #ORBITALS new part END
	 done
	
	 
    elif [[ $at =~ $re ]] ; then
	 i=$at
	 echo 'plotting orbitals form atom '$at
	 atomtype=$(sed -n "$i p" $dir/atomtypes) #daje H, Ca, itp o takim indeksie jak tu
	 echo $atomtype >> $dir/atomtypes_list
	 #echo $atomtype 
	 
	 j=$(($at+1))
	 echo 'atom '$at
     #echo 'atom '$i $j
	 #wycina plik od atomu i do atomu i+1 (CO GDY NIE MA JUŻ ATOMU i+1 ? )
	 if [[ $at = $n_atoms ]] ; then
	  sed -n "/ion $i\"/, /dos/p" vasprun.xml | head -n -3  > $dir/dos-at$at
	 else
	  sed -n "/ion $i\"/, /ion $j\"/p" vasprun.xml > $dir/dos-at$at	 
	 fi	 
	  
	 #wycina 1-szą linię i usuwa ostatnie 2
	 sed -n '/spin 1/,/spin 2/p' $dir/dos-at$at | sed '1d' | head -n -2 > $dir/dos-at$at-up
	 #wycina 1-szą linię i usuwa ostatnie 3
	 sed -n '/spin 2/,$p'        $dir/dos-at$at | sed '1d' | head -n -3 > $dir/dos-at$at-down
	 ##dodaje kolumny w rzędzie od 3 do 11 co 1 jako "sum"; drukuje $2 i tę "sum" i drukuje to do pliku
	   #ORBITALS new part START
	 if [[ "$at_orbital" == *"al"* ]]; then
	  echo 4 
	  awk -v max=$max_column '{sum=0;for(i=3;i<=max;++i){sum+=$i}; print $2, sum}' $dir/dos-at$at-up   > $dir/dos-at$at-orb-$at_orbital-up-sum
	  awk -v max=$max_column '{sum=0;for(i=3;i<=max;++i){sum+=$i}; print $2, sum}' $dir/dos-at$at-down > $dir/dos-at$at-orb-$at_orbital-down-sum
	 else
	 #dodaje kolumny w rzędzie od 3 do 11 co 1 jako "sum"; drukuje $2 i tę "sum" i drukuje to do pliku
	  echo 5
	  awk -v z=$orbital_column '{print $2, $z}'                $dir/dos-at$at-up   > $dir/dos-at$at-orb-$at_orbital-up-sum
	  awk -v z=$orbital_column '{print $2, $z}'                $dir/dos-at$at-down > $dir/dos-at$at-orb-$at_orbital-down-sum
	 fi
	 

	else 
	 echo 'ERROR Provided atom is not a number'
    fi
	
   echo $at $atomtype
   cp $dir/dos-at$at-orb-$at_orbital-up-sum      gr-up$x-atoms-$at-orb-$at_orbital-type-$atomtype
   cp $dir/dos-at$at-orb-$at_orbital-down-sum    gr-dn$x-atoms-$at-orb-$at_orbital-type-$atomtype
   #ls -1B group*atoms*type*
	   #ORBITALS new part END
   
   done
 fi
fi




#rm -f xx02
#for i in xx**; do sed -i  's/[A-Za-z]*//g' $i; sed '1d' $i | tac | sed '1,2d' | tac > x$i ; done

csplit -z  $dir/dos_all.dat /spin/ '{*}' > xxxx
cp xx00 $dir/dos_tot_up
cp xx01 $dir/dos_tot_down
###usuwanie plików z wyeksrtahowanym dos_up i dos_down
#mv  xx* $dir
rm -f xx?? 
rm -f xxx??
#END OF REDRAW ALL THE DATA##################
fi


ef=`awk '/efermi/ {print $3}' vasprun.xml`

#GDY NIE MA 'ATOMS' CZYLI ROBIMY DOS-y BEZ PODZIAŁU NA ATOMY
#xx00 to tot_s_up a xxx01 to tot_s_down
for i in $dir/dos_tot_up $dir/dos_tot_down ; do
#echo $i
cp $i $dir/dos_tmp
sed -i '1d' $dir/dos_tmp
#eps
#cat >plotfile1_eps<<!
#set term postscript enhanced eps colour lw 2 "Helvetica" 20
#set output "dosplot.eps"
##plot "dos_tmp" using (\$1-$ef):(\$2) w lp
#plot "dos_tmp" using (\$1-$ef):(\$2) w lines
#
#!


#set term png  14 size 1920,1080
#plot "dos.dat" using (\$1-$ef):(\$2) w lp - lp = points connected with lines

#ZROBIĆ SVG!!! #colour lw 2 "Helvetica" 20 
cat >$dir/plotfile1_svg<<!
set term svg size 960,540 font "Arial,14" fontscale 1.333333333333333 
set output "dosplot.svg"
set xrange [$x_min:$x_max]
#set yrange [$y_min:$y_max]
plot "$dir/dos_tmp"  using (\$1-$ef):(\$2) w lines
!

#png
cat >$dir/plotfile1_png<<!
set term png  14 size 960,540
set output "dosplot.png"
set xrange [$x_min:$x_max]
#set yrange [$y_min:$y_max]
plot "$dir/dos_tmp" using (\$1-$ef):(\$2) with lines
!

#png Large
#cat >plotfile1_png_L<<!
##set term png  14 size 960,540
#set term png  14 size 3840,2160
#set output "dosplot_L.png"
#set xrange [$x_min:$x_max]
#set yrange [$y_min:$y_max]
##plot "dos.dat" using (\$1-$ef):(\$2) w lp
#plot "dos_tmp" using (\$1-$ef):(\$2) with lines
#!


gnuplot -persist $dir/plotfile1_svg
gnuplot -persist $dir/plotfile1_png
#gnuplot -persist plotfile1_png_L


mv dosplot.svg $i.svg 
mv dosplot.png $i.png 
#mv dosplot_L.png $i-L.png 


done


#mv dosplot-xxx00.eps	dosplot-s_up.eps
#mv dosplot-xxx00.png 	dosplot-s_up.png
#mv dosplot_L-xxx00.png 	dosplot-s_up_L.png 
#mv dosplot-xxx01.eps 	dosplot-s_down.eps
#mv dosplot-xxx01.png 	dosplot-s_down.png
#mv dosplot_L-xxx01.png 	dosplot-s_down_L.png

#DOS_up and DOS_down razem
#zapisuje rysunek "dosplot-s_up-s_down.png" 
cat >$dir/plotfile_dos_all_svg<<!
set term svg size 960,540 font "Arial,14" fontscale 1.333333333333333 
set output "dos_tot_all.svg"
set title 'Total spin_up and spin_down'
set xrange [$x_min:$x_max]
#set yrange [$y_min:$y_max]
plot "$dir/dos_tot_up" using (\$1-$ef):(\$2) w lines, \
     "$dir/dos_tot_down" using (\$1-$ef):(\$2*-1) w lines
!

cat >$dir/plotfile_dos_all_png<<!
set term png  14 size 960,540
set output "dos_tot_all.png"
set title 'Total spin_up and spin_down'
set xrange [$x_min:$x_max]
#set yrange [$y_min:$y_max]
plot "$dir/dos_tot_up" using (\$1-$ef):(\$2) w lines, \
     "$dir/dos_tot_down" using (\$1-$ef):(\$2*-1) w lines
!


#jeśli nie ma 3 argumentów, i nie ma opcji 'redraw'
#wyrzuca rysunek "dosplot-s_up-s_down" na X-terminal z możliwością przybliżenia/oddalenia/przesunięcia 
#(shift+scroll = lewo-prawo)
###if [ $# -lt 3 ] && ! [[ $@ == *"draw"* ]]  ;   then
####echo 'lol'
###cat >$dir/plotfile_dos_tot_all_zoom<<!
###set xzeroaxis
###set title 'Total spin_up and spin_down'
###set xrange [$x_min:$x_max]
####set yrange [$y_min:$y_max]
###plot "$dir/dos_tot_up" using (\$1-$ef):(\$2) w lines, \
###     "$dir/dos_tot_down" using (\$1-$ef):(\$2*-1) w lines
####plot "dos_tot_up" using (\$1-$ef):(\$2) w lines lt -1,  "$dir/dos_tot_down" using (\$1-$ef):(\$2*-1) w lines lt -1, "$dir/dos-at1-up-sum" using (\$1-$ef):(\$2) w lines
#####OPCJA 2 - rysunki 1 i 2 się rysują, a program rysuje 3 i sie zatrzymuje, ale można zoomować
###pause mouse keypress
###!
###fi

echo $arguments


#if [ $# -gt 3 ] || [[ $3 == *"draw"* ]];   then
# wersja na lub
if [[ "$@" == *"atoms"* ]] || [[ "$@" == *"draw"* ]] || [[ "$@" == *"orbital"* ]];   then
echo 'mode='$mode

LINECOLORS_bash="red web-green blue goldenrod cyan magenta"
RESOLUTION_bash="1920,1080"
res_h=1920
res_w=1080
font_axis_png=28
font_key_png=$((font_axis_png / 4 * 3))


#pDOS spin-all  file PNG
cat >$dir/plotfile_dos_pdos_all_png<<!
#set title 'Total spin-up, total spin-down and pDOS'
#set nokey # wyłącza legende

#set term png $font_axis_png size $res_h,$res_w
#set key horizontal outside left top font ",$font_key_png"

set term pngcairo   font "Arial,$font_axis_png" size $res_h,$res_w
set key horizontal outside left top font ",$font_key_png"

set output "dos_tot_pdos_all.png"

###PART1 start

LINECOLORS = system('echo $LINECOLORS_bash')
myLinecolor(i) = word(LINECOLORS,i)

set xrange [$x_min:$x_max]
set yrange [$y_min:$y_max]
set arrow from 0, graph 0 to 0, graph 1 nohead lt rgb "gray"
set termoption enhanced
set ylabel "DOS" 
set xlabel 'E - E_F / eV' 

list_up=system('ls -1B   gr-up*atoms*type*')
list_down=system('ls -1B gr-dn*atoms*type*')

#ta linia wskazuje, że co liczbę serii wskazaną przez listę elementów w list_up styl linii się restartuje (hope so)
set linetype cycle words(list_up)
i_max=words(list_up)

plot for [i=1:words(list_up)] word(list_up, i) using (\$1-$ef):(\$2) w lines lc rgb myLinecolor(i) title word(list_up, i), \
     for [i=1:words(list_down)] word(list_down, i) using (\$1-$ef):(\$2*-1) w lines lc rgb myLinecolor(i) notitle, \
	 "$dir/dos_tot_up" using (\$1-$ef):(\$2) w lines lt rgb "black" title "total dos" , \
	 "$dir/dos_tot_down" using (\$1-$ef):(\$2*-1) w lines lt rgb "black" notitle

###PART1 end
!



scale=0.5
mod_res_h=$(awk "BEGIN {print $res_h*$scale}")
mod_res_w=$(awk "BEGIN {print $res_w*$scale}")
mod_font_axis_png=$(awk "BEGIN {print $font_axis_png*$scale}")
mod_font_key_png=$(awk "BEGIN {print $font_key_png*$scale}")

#pDOS spin-up file PNG
cat >$dir/plotfile_dos_pdos_up_png<<!
#set title 'Total spin-up and pDOS-up'
#set nokey # wyłącza legende
##tryb high-resolution
##tryb low-resolution
set term png  $mod_font_axis_png size $mod_res_h,$mod_res_w
set key horizontal outside left top font ",$mod_font_key_png"

set output "dos_tot_pdos_up.png"

###PART1 start

LINECOLORS = system('echo $LINECOLORS_bash')
myLinecolor(i) = word(LINECOLORS,i)

set xrange [$x_min:$x_max]
set yrange [$y_min:$y_max]
set arrow from 0, graph 0 to 0, graph 1 nohead lt rgb "gray"
set termoption enhanced
set ylabel "DOS" 
set xlabel 'E - E_F / eV' 

list_up=system('ls -1B   gr-up*atoms*type*')
list_down=system('ls -1B gr-dn*atoms*type*')

#ta linia wskazuje, że co liczbę serii wskazaną przez listę elementów w list_up styl linii się restartuje (hope so)
set linetype cycle words(list_up)
i_max=words(list_up)

plot for [i=1:words(list_up)] word(list_up, i) using (\$1-$ef):(\$2) w lines lc rgb myLinecolor(i) title word(list_up, i), \
     "$dir/dos_tot_up" using (\$1-$ef):(\$2) w lines lt rgb "black" title "total dos" 

###PART1 end
!


#pDOS spin-all file SVG
cat >$dir/plotfile_dos_pdos_all_svg<<!
#set title 'Total spin-up, total spin-down and pDOS'
#set nokey # wyłącza legende

set term svg size 960,540 font "Arial,14" fontscale 1.3333 
set key horizontal outside left top font ",12"
#set key vertical outside right top font ",12"
set output "dos_tot_pdos_all.svg"

#set linetype colour sequence:
# set linetype 1 lc rgb "red" #lw 2 pt 0
# set linetype 2 lc rgb "green"   #lw 2 pt 7
# set linetype 3 lc rgb "cyan"        #lw 2 pt 6 pi -1
# set linetype 4 lc rgb "blue"   #lw 2 pt 5 pi -1
# set linetype 5 lc rgb "goldenrod"        #lw 2 pt 8
# set linetype 6 lc rgb "brown" #lw 2 pt 3
# set linetype 7 lc rgb "orange"       #lw 2 pt 11
# set linetype 8 lc rgb "dark-red"   #lw 2

###PART1 start

LINECOLORS = system('echo $LINECOLORS_bash')
myLinecolor(i) = word(LINECOLORS,i)

set xrange [$x_min:$x_max]
set yrange [$y_min:$y_max]
set arrow from 0, graph 0 to 0, graph 1 nohead lt rgb "gray"
set termoption enhanced
set ylabel "DOS" 
set xlabel 'E - E_F / eV' 

list_up=system('ls -1B   gr-up*atoms*type*')
list_down=system('ls -1B gr-dn*atoms*type*')

#ta linia wskazuje, że co liczbę serii wskazaną przez listę elementów w list_up styl linii się restartuje (hope so)
set linetype cycle words(list_up)
i_max=words(list_up)

plot for [i=1:words(list_up)] word(list_up, i) using (\$1-$ef):(\$2) w lines lc rgb myLinecolor(i) title word(list_up, i), \
     for [i=1:words(list_down)] word(list_down, i) using (\$1-$ef):(\$2*-1) w lines lc rgb myLinecolor(i) notitle, \
	 "$dir/dos_tot_up" using (\$1-$ef):(\$2) w lines lt rgb "black" title "total dos" , \
	 "$dir/dos_tot_down" using (\$1-$ef):(\$2*-1) w lines lt rgb "black" notitle

###PART1 end
!

#pDOS spin-up file SVG
cat >$dir/plotfile_dos_pdos_up_svg<<!
#set title 'Total spin-up and pDOS-up'
#set nokey # wyłącza legende

set term svg size 960,540 font "Arial,14" fontscale 1.3333 
set key horizontal outside left top font ",12"
set output "dos_tot_pdos_up.svg"

#set linetype colour sequence:
# set linetype 1 lc rgb "red" #lw 2 pt 0
# set linetype 2 lc rgb "green"   #lw 2 pt 7
# set linetype 3 lc rgb "cyan"        #lw 2 pt 6 pi -1
# set linetype 4 lc rgb "blue"   #lw 2 pt 5 pi -1
# set linetype 5 lc rgb "goldenrod"        #lw 2 pt 8
# set linetype 6 lc rgb "brown" #lw 2 pt 3
# set linetype 7 lc rgb "orange"       #lw 2 pt 11
# set linetype 8 lc rgb "dark-red"   #lw 2

###PART1 start

LINECOLORS = system('echo $LINECOLORS_bash')
myLinecolor(i) = word(LINECOLORS,i)

set xrange [$x_min:$x_max]
set yrange [$y_min:$y_max]
set arrow from 0, graph 0 to 0, graph 1 nohead lt rgb "gray"
set termoption enhanced
set ylabel "DOS" 
set xlabel 'E - E_F / eV' 

list_up=system('ls -1B   gr-up*atoms*type*')
list_down=system('ls -1B gr-dn*atoms*type*')

#ta linia wskazuje, że co liczbę serii wskazaną przez listę elementów w list_up styl linii się restartuje (hope so)
set linetype cycle words(list_up)
i_max=words(list_up)

plot for [i=1:words(list_up)] word(list_up, i) using (\$1-$ef):(\$2) w lines lc rgb myLinecolor(i) title word(list_up, i), \
	 "$dir/dos_tot_up" using (\$1-$ef):(\$2) w lines lt rgb "black" title "total dos" 

###PART1 end
!

#czytanie rysunku w terminalu X11
#  cat >$dir/plotfile_dos_tot_all_zoom<<!
#  set terminal x11 
#  #set terminal qt font "Arial,14" size $res_h,$res_w #ok, ale sie zacina na poczatku
#  #set terminal qt size $res_h,$res_w
#  #set terminal tgif 
#  #set terminal wxt
#  #set terminal windows
#  #set terminal xlib
#  #set terminal xterm
#  set xzeroaxis
#  set title 'Total spin-up, total spin-down and pDOS'
#  
#  ###PART1 start
#  
#  LINECOLORS = system('echo $LINECOLORS_bash')
#  myLinecolor(i) = word(LINECOLORS,i)
#  
#  set xrange [$x_min:$x_max]
#  set yrange [$y_min:$y_max]
#  set arrow from 0, graph 0 to 0, graph 1 nohead lt rgb "gray"
#  set termoption enhanced
#  set ylabel "DOS" 
#  set xlabel 'E - E_F / eV' 
#  
#  list_up=system('ls -1B   gr-up*atoms*type*')
#  list_down=system('ls -1B gr-dn*atoms*type*')
#  
#  #ta linia wskazuje, że co liczbę serii wskazaną przez listę elementów w list_up styl linii się restartuje (hope so)
#  set linetype cycle words(list_up)
#  i_max=words(list_up)
#  
#  plot for [i=1:words(list_up)] word(list_up, i) using (\$1-$ef):(\$2) w lines lc rgb myLinecolor(i) title word(list_up, i), \
#       for [i=1:words(list_down)] word(list_down, i) using (\$1-$ef):(\$2*-1) w lines lc rgb myLinecolor(i) notitle, \
#  	 "$dir/dos_tot_up" using (\$1-$ef):(\$2) w lines lt rgb "black" title "total dos" , \
#  	 "$dir/dos_tot_down" using (\$1-$ef):(\$2*-1) w lines lt rgb "black" notitle
#  
#  ###PART1 end
#  #inne przydatne opcje:
#  #for [i in list_up] i using (\$1-$ef):(\$2) w lines title i,
#  #for [i in list_down] i using (\$1-$ef):(\$2*-1) w lines notitle , 
#  #LINEWIDTHS = '1.0  4.0   0.0   0.0     0.0'
#  #list_names=system('cat atomtypes_list')
#  #elements=system('wc -l atomtypes_list | cut -d " " -f 1 ')
#  #for [i=1:elements] word(list_up, i) using (\$1-$ef):(\$2) w lines word(list_names, i) , \		  
#  #plot for [i=1:1000] 'dos-at'.i.'-down-sum' using (\$1-$ef):(\$2*-1) w lines 'Flow '.i
#  ##OPCJA 2 - rysunki 1 i 2 się rysują, a program rysuje 3 i sie zatrzymuje, ale można zoomować
#  pause mouse keypress
#  !


#cat >plotfile_dos_pdos_all_RAW_png<<!
##set title 'Total spin-up, total spin-down and pDOS'
##set nokey # wyłącza legende
#set term png $font_axis_png size $res_h,$res_w
#set key horizontal outside left top font ",$font_key_png"
#
#set output "dos_tot_pdos_all.png"
#
####PART1 start
#
#LINECOLORS = system('echo $LINECOLORS_bash')
#myLinecolor(i) = word(LINECOLORS,i)
#
#set xrange [$x_min:$x_max]
#set yrange [$y_min:$y_max]
#set arrow from 0, graph 0 to 0, graph 1 nohead lt rgb "gray"
#set termoption enhanced
#set ylabel "DOS" 
#set xlabel 'E - E_F / eV' 
#
#list_up=system('ls -1B gr-up*atoms*type*')
#list_down=system('ls -1B gr-dn*atoms*type*')
#
##ta linia wskazuje, że co liczbę serii wskazaną przez listę elementów w list_up styl linii się restartuje (hope so)
#set linetype cycle words(list_up)
#i_max=words(list_up)
#
#plot for [i=1:words(list_up)] word(list_up, i) using (\$1-$ef):(\$2) w lines lc rgb myLinecolor(i) title word(list_up, i), \
#     for [i=1:words(list_down)] word(list_down, i) using (\$1-$ef):(\$2*-1) w lines lc rgb myLinecolor(i) notitle, \
#	 "dos_tot_up" using (\$1-$ef):(\$2) w lines lt rgb "black" title "total dos" , \
#	 "dos_tot_down" using (\$1-$ef):(\$2*-1) w lines lt rgb "black" notitle
#
####PART1 end
#!

list=$(ls -1v $dir | grep 'dos-at' | grep 'up-sum' | grep -v 'temp')
first=$(echo $list | awk  '{print $1}' )
awk '{print $1}' $dir/$first > $dir/temp-dos-up-stacked
unset arr_temp
declare -a arr_temp
j=1
for i in $list; do
  awk '{print $2}' $dir/$i > $dir/temp-"$i"
  arr_temp+=("$dir/temp-$i")
  j=$((j+1))
done
paste $dir/temp-dos-up-stacked ${arr_temp[@]} > $dir/temp-dos-up-stacked-all
echo 'Figure stacked of dos spin-up for gr-ups '$list

cat >$dir/plotfile_dos_stack_up<<!
##tryb high-resolution
set term pngcairo   font "Arial,$font_axis_png" size $res_h,$res_w
set key horizontal outside left top font ",$font_key_png"

set output "dos_tot_pdos_stack_up.png"

###PART2 start

LINECOLORS = system('echo $LINECOLORS_bash')
myLinecolor(i) = word(LINECOLORS,i)

set xrange [$x_min:$x_max]
set yrange [$y_min:$y_max]
set arrow from 0, graph 0 to 0, graph 1 nohead lt rgb "gray"
set termoption enhanced
set ylabel "DOS" 
set xlabel 'E - E_F / eV' 

list_up=system('ls -1B   gr-up*atoms*type*')
list_down=system('ls -1B gr-dn*atoms*type*')
###PART1 end

#ta linia wskazuje, że co liczbę serii wskazaną przez listę elementów w list_up styl linii się restartuje (hope so)
set linetype cycle words(list_up)
#i_max=words(list_up)


#set pointsize 0.8

#set border 11
#set xtics out
#set tics front
#set key below
# "$dir/temp-dos-down-stacked-all" using (\$1-$ef):(sum [col=i:$j] column(col)*-1) with filledcurves x1 lc rgb myLinecolor(i)
plot \
  for [i=2:$j:1] \
    "$dir/temp-dos-up-stacked-all" using (\$1-$ef):(sum [col=i:$j] column(col)) with filledcurves fc rgb myLinecolor(i-1) \
	title word(list_up, i-1), \
	"$dir/dos_tot_up" using (\$1-$ef):(\$2) w lines lt rgb "black" title "total dos spin-up" 
!

list=$(ls -1v $dir | grep 'dos-at' | grep 'down-sum' | grep -v 'temp')
first=$(echo $list | awk  '{print $1}' )
awk '{print $1}' $dir/$first > $dir/temp-dos-down-stacked
unset arr_temp
declare -a arr_temp
j=1
for i in $list; do
  awk '{print $2}' $dir/$i > $dir/temp-"$i"
  arr_temp+=("$dir/temp-$i")
  j=$((j+1))
done
paste $dir/temp-dos-down-stacked ${arr_temp[@]} > $dir/temp-dos-down-stacked-all
echo 'Figure stacked of dos spin-down for gr-dns '$list

cat >$dir/plotfile_dos_stack_dn<<!
##tryb high-resolution
set term pngcairo   font "Arial,$font_axis_png" size $res_h,$res_w
set key horizontal outside left top font ",$font_key_png"

set output "dos_tot_pdos_stack_down.png"

###PART2 start

LINECOLORS = system('echo $LINECOLORS_bash')
myLinecolor(i) = word(LINECOLORS,i)

set xrange [$x_min:$x_max]
set yrange [$y_min:$y_max] reverse
set arrow from 0, graph 0 to 0, graph 1 nohead lt rgb "gray"
set termoption enhanced
set ylabel "DOS" 
set xlabel 'E - E_F / eV' 

list_up=system('ls -1B   gr-up*atoms*type*')
list_down=system('ls -1B gr-dn*atoms*type*')
###PART1 end

#ta linia wskazuje, że co liczbę serii wskazaną przez listę elementów w list_up styl linii się restartuje (hope so)
set linetype cycle words(list_down)
#i_max=words(list_up)

plot \
for [i=2:$j:1] \
    "$dir/temp-dos-down-stacked-all" using (\$1-$ef):(sum [col=i:$j] column(col)*-1) with filledcurves x1 lc rgb myLinecolor(i) \
	title word(list_down, i-1), \
	"$dir/dos_tot_down" using (\$1-$ef):(\$2*-1) w lines lt rgb "black" title "total dos spin-down" 
!

gnuplot -persist $dir/plotfile_dos_stack_up
gnuplot -persist $dir/plotfile_dos_stack_dn
gnuplot -persist $dir/plotfile_dos_pdos_all_png
gnuplot -persist $dir/plotfile_dos_pdos_all_svg
gnuplot -persist $dir/plotfile_dos_pdos_up_png
gnuplot -persist $dir/plotfile_dos_pdos_up_svg

fi

gnuplot -persist $dir/plotfile_dos_all_svg
gnuplot -persist $dir/plotfile_dos_all_png
#gnuplot -persist plotfile5


#gnuplot -persist plotfile_dos_tot_all_zoom

#gnuplot -geometry 1600x800 $dir/plotfile_dos_tot_all_zoom

####usuwanie komend gnuplot'a
#rm -f plotfile*
#rm -f dos-at*down dos-at*up dos-at? dos-at??
#
##rm -f dos_tmp 
##rm -f dos-at* 


arguments_=$(echo $arguments | sed  's/ /_/g')
for i in png svg; do
for j in dos_tot_pdos*_all.$i ; do
name=$(echo "${j%%.*}")
cp $j "$name"_"$arguments_.$i"
rm -f $j
done
for j in dos_tot_pdos*_up.$i ; do
name=$(echo "${j%%.*}")
cp $j "$name"_"$arguments_.$i"
rm -f $j
done
done

#folder ze wszystkimi danymi - lepiej usuwać chyba że do analizy outputu
rm -f -r gnu-tmp-*

rm -f dos_tot_all.png dos_tot_all.svg dos_tot_pdos_all.png dos_tot_pdos_all.svg dos_tot_pdos_down_stack.png dos_tot_pdos_stack_down.png dos_tot_pdos_stack_up.png dos_tot_pdos_up.png dos_tot_pdos_up.svg dos_tot_pdos_up_stack.png



