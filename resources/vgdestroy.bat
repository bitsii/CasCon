
mkdir Vg
cd Vg
mkdir %1
cd %1

vagrant destroy -f

cd ..

del /q /s %1\*.*
rd /s /q %1
rmdir %1

cd ..
