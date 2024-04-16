/* OR Etat 2019 *****- DEPENSES -********/ 

cd F:\ROR\ANALYSE\2019\dofiles

* depenses = depenses alimentaires (dont autoconsommation)+ PPNnoali + mo_perm +
* + transferts cedes + depenses d'investissements + autres depenses courantes

/***** depenses alimentaires*****/

	* en periode hors soudure
use "F:\ROR\DATA\2019\Stata\res_d1aa.dta", clear
do dofileJ5
gen depali_horsoud=d1aa2
collapse(sum)depali_horsoud, by(j5 year)
save "F:\ROR\ANALYSE\2019\resultfiles\depali_horsoud_2019.dta", replace

* en periode de soudure
use "F:\ROR\DATA\2019\Stata\res_d1ab.dta", clear
do dofileJ5
gen depali_soud=d1ab2
collapse(sum)depali_soud, by(j5 year)
save "F:\ROR\ANALYSE\2019\resultfiles\depali_soud_2019.dta", replace

use "F:\ROR\ANALYSE\2019\resultfiles\depali_horsoud_2019.dta", clear
merge 1:1 j5 year using "F:\ROR\ANALYSE\2019\resultfiles\depali_soud_2019.dta", nogenerate
gen depali = depali_horsoud + depali_soud
keep j5 year depali
sort j5 year
save "F:\ROR\ANALYSE\2019\resultfiles\depali_2019.dta", replace

* achat de PPN non alimentaires
* en periode hors soudure

use "F:\ROR\DATA\2019\Stata\res_d1ba.dta", clear
do dofileJ5
gen ppnoali_horsoud=d1ba
collapse(sum)ppnoali_horsoud, by(j5 year)
save "F:\ROR\ANALYSE\2019\resultfiles\ppnoali_horsoud_2019.dta", replace

* en periode de soudure
use "F:\ROR\DATA\2019\Stata\res_d1bb.dta", clear
do dofileJ5
gen ppnoali_soud=d1bb
collapse(sum)ppnoali_soud, by(j5 year)
save "F:\ROR\ANALYSE\2019\resultfiles\ppnoali_soud_2019.dta", replace

use "F:\ROR\ANALYSE\2019\resultfiles\ppnoali_horsoud_2019.dta", clear
merge 1:1 j5 year using "F:\ROR\ANALYSE\2019\resultfiles\ppnoali_soud_2019.dta", nogenerate
gen ppnoali = ppnoali_horsoud + ppnoali_soud
keep j5 year ppnoali
sort j5 year
save "F:\ROR\ANALYSE\2019\resultfiles\ppnoali_2019.dta", replace

use "F:\ROR\ANALYSE\2019\resultfiles\depali_2019.dta", clear
merge 1:1 j5 year using "F:\ROR\ANALYSE\2019\resultfiles\ppnoali_2019.dta", nogenerate
sort j5 year
save "F:\ROR\ANALYSE\2019\resultfiles\PPN_2019.dta", replace

* les autoconsommations: en riz, ,en autres cultures et en elevage

* autoconsommations en riz
use "F:\ROR\DATA\2019\Stata\res_dc1.dta", clear
do dofileJ5
gen conso_riz = dc09
keep j5 year conso_riz
recode conso_riz (miss=0)
sort j5 year
save "F:\ROR\ANALYSE\2019\resultfiles\conso_riz_2019.dta", replace

* valorisation monetaire a partir du prix moyen pondere
use "F:\ROR\ANALYSE\2019\resultfiles\conso_riz_2019.dta", clear
gen obs=substr(j5,1,2)
sort obs year
merge m:1 obs year using "F:\ROR\ANALYSE\2019\resultfiles\px_paddy_obs_2019.dta", nogenerate
gen conso_riz_val = conso_riz * pxpaddy_obs
drop pxpaddy_obs conso_riz obs
sort j5 year
save "F:\ROR\ANALYSE\2019\resultfiles\conso_riz_val_2019.dta", replace

* autoconsommations en autres cultures

use "F:\ROR\DATA\2019\Stata\res_c.dta", clear
do dofileJ5
egen cult=concat(c1 c37)
gen conso_cu=c7
collapse(sum)conso_cu, by(j5 cult year)
save "F:\ROR\ANALYSE\2019\resultfiles\conso_cu_2019.dta", replace

* valorisation monetaire a partir du prix moyen pondere

use "F:\ROR\ANALYSE\2019\resultfiles\conso_cu_2019.dta", clear
sort cult year
merge m:m cult year using "F:\ROR\ANALYSE\2019\resultfiles\prix_cu_2019.dta", nogenerate
gen conso_cu_val = conso_cu*prix_cu
collapse(sum)conso_cu_val, by(j5 year)
save "F:\ROR\ANALYSE\2019\resultfiles\conso_cu_val_2019.dta", replace

* autoconsommation en elevage
* conso_ani_val dans conso_ani_val_2019.dta

* autoconsommations en produits de peche

use "F:\ROR\DATA\2019\Stata\res_ppec.dta", clear
do dofileJ5
gen conso_peche=ppec_g
collapse(sum)conso_peche, by(j5 ppec_lig year)
save "F:\ROR\ANALYSE\2019\resultfiles\conso_peche_2019.dta", replace

use "F:\ROR\ANALYSE\2019\resultfiles\conso_peche_2019.dta", clear
sort ppec_lig year
merge m:m ppec_lig year using "F:\ROR\ANALYSE\2019\resultfiles\prix_peche_2019.dta", nogenerate
gen conso_peche_val = conso_peche * prix_peche
collapse(sum)conso_peche_val, by(j5 year)
save "F:\ROR\ANALYSE\2019\resultfiles\conso_peche_val_2019.dta", replace

* transferts cedes
* dans transced_2019.dta

* depenses en main d'oeuvre permanente
* dans mo_perm_2019.dta

* depenses d'investissement: achat de bovin + achat de materiels agricoles

* achat de zebus
* dans achanimoval_2019.dta

* achat de materiels agricoles et autres depenses courantes

use "F:\ROR\DATA\2019\Stata\res_d_hafa.dta", clear
do dofileJ5
recode d2a d2b d2c d3 d4 d5 d6 d7 d8 d9 d10 d11 d12 d13 d14 (miss=0)
rename d5 ach_materiel
gen dep_courantes=d2a+d2b+d2c+d3+d4+d6+d7+d8+d9+d10+d11+d12+d13+d14
keep j5 year ach_materiel dep_courantes
sort j5 year
save "F:\ROR\ANALYSE\2019\resultfiles\dep_courantes_2019.dta", replace

* merging files

use "F:\ROR\ANALYSE\2019\resultfiles\PPN_2019.dta", clear
merge 1:1 j5 year using "F:\ROR\ANALYSE\2019\resultfiles\conso_riz_val_2019.dta", nogenerate
merge 1:1 j5 year using "F:\ROR\ANALYSE\2019\resultfiles\conso_cu_val_2019.dta", nogenerate
merge 1:1 j5 year using "F:\ROR\ANALYSE\2019\resultfiles\conso_ani_val_2019.dta", nogenerate
merge 1:1 j5 year using "F:\ROR\ANALYSE\2019\resultfiles\conso_peche_val_2019.dta", nogenerate
merge 1:1 j5 year using "F:\ROR\ANALYSE\2019\resultfiles\mo_perm_2019.dta", nogenerate
merge 1:1 j5 year using "F:\ROR\ANALYSE\2019\resultfiles\transced_2019.dta", nogenerate
merge 1:1 j5 year using "F:\ROR\ANALYSE\2019\resultfiles\achanimoval_2019.dta", nogenerate
merge 1:1 j5 year using "F:\ROR\ANALYSE\2019\resultfiles\dep_courantes_2019.dta", nogenerate

recode depali ppnoali conso_riz_val conso_cu_val conso_ani_val conso_peche_val ///
mo_perm_mo mo_perm_nomo transcedmo transcednomo ach_materiel achzebuval dep_courantes(miss=0)
gen autoconso = conso_riz_val + conso_cu_val + conso_ani_val + conso_peche_val
gen depali2=depali+autoconso
gen mo_perm=mo_perm_mo+mo_perm_nomo
gen dep_invest=ach_materiel+achzebuval
gen transced=transcedmo+transcednomo
gen deptot=depali2+ppnoali+mo_perm+transced+dep_invest+dep_courantes
sort j5 year
save "F:\ROR\ANALYSE\2019\resultfiles\deptot_2019.dta", replace

* controle revenu_depenses

use "F:\ROR\ANALYSE\2019\resultfiles\income_2019.dta", clear
merge 1:1 j5 year using "F:\ROR\ANALYSE\2019\resultfiles\deptot_2019.dta", nogenerate
merge 1:1 j5 year using "F:\ROR\ANALYSE\2019\resultfiles\menage_2019.dta", nogenerate

gen marge = revtot - deptot

count if marge<0
* 699
count if marge<-1000000
*239

gen deptete=deptot/taille
gen deptetej=deptete/365
edit j5 rev_riz rev_cu revel revpeche decap revtot deptot marge if marge<0
edit j5 rev_riz rev_cu revel revpeche decap revtot deptot marge if revtot>10000000

* marge<-5000000
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0314022"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0316009"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0324031"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0325006"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0325076"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0331015"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0325022"

edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="1632155"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="1643096"

* marge compris entre -5000000 et -2000000
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0311015"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0311028"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0311050"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0311060"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0311068"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0311073"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0311119"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0311137"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0312056"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0313033"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0313087"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0313093"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0313101"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0314015"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0314063"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0314067"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0315031"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0316001"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0316002"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0316024"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0316027"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0319001"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0319006"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0319067"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0321036"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0322037"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0323029"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0323038"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0323051"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0323057"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0323069"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0324040"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0324046"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0325008"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0325012"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0331001"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0331016"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0331019"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0331054"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0334018"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0334034"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0336011"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0336019"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0336022"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0336025"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0336051"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0336052"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0336053"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0336983"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0337028"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0337045"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="0337057"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="1621088"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="1621093"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="1622091"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="1623093"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="1623104"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="1632131"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="1633065"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="1641132"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="1643104"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="1651218"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="2111028"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="2111029"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="2132043"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="2133015"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="2141035"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="2141038"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="2142087"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="2151085"
edit depali autoconso ppnoali ach_materiel dep_courantes mo_perm dep_invest transced deptot if j5=="2151088"




