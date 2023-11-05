
mkdir Vg
cd Vg
mkdir %3
cd %3
REM vagrant init generic/ubuntu2004 >nul
copy /y ..\..\App\BAM\Vagrantfile . >nul
vagrant up >nul
