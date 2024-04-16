/* OR Etat 2019 *****- ANALYSE SUR LE REVENU -********/ 

cd "F:\ROR\ANALYSE\2019\resultfiles"

use income_2019, clear
merge 1:1 j5 year using deptot_2019, nogenerate
merge 1:1 j5 year using menage_2019, nogenerate

gen revtot_tete = revtot/(taille*1000)
gen revcou_tete = revcou/(taille*1000)
gen revexcept_tete = revexcept/(taille*1000)

log using "F:\ROR\ANALYSE\2019\logfiles\revenu_ambovombe.smcl", replace

* les niveaux de revenu par tete (en milliers d'Ariary)

* revenu total par tete
	* par commune
table commune year if j0==16, c(m revtot_tete med revtot_tete sd revtot_tete)format(%5.0fc)
	* dans l'observatoire
table j0 year if j0==16, c(m revtot_tete med revtot_tete sd revtot_tete)format(%5.0fc)

* revenu courant par tete
	* par commune
table commune year if j0==16, c(m revcou_tete med revcou_tete sd revcou_tete)format(%5.0fc)
	* dans l'observatoire
table j0 year if j0==16, c(m revcou_tete med revcou_tete sd revcou_tete)format(%5.0fc)

* revenu exceptionnel par tete
	* par commune
table commune year if j0==16, c(m revexcept_tete med revexcept_tete sd revexcept_tete)format(%5.0fc)
	* dans l'observatoire
table j0 year if j0==16, c(m revexcept_tete med revexcept_tete sd revexcept_tete)format(%5.0fc)

* revenu exceptionnel
	* pourcentage des menages ayant enregistre du revenu exceptionnel
	gen men_except="Oui" if revexcept>0
	replace men_except="Non" if revexcept==0
	bysort year: tab j42 men_except if j0==16, row nof
	* niveau du revenu exceptionnel chez les menages concernes
	table j42 if revexcept>0 & j0==16, c(med revexcept_tete freq)
	table obs if revexcept>0 & j0==16, c(med revexcept_tete freq)

* les composantes du revenu

* riziculture
gen rev_riz1= rev_riz/1000
table j42 if rev_riz>0 & j0==16, c(m rev_riz1 med rev_riz1 freq m taille)
table obs if rev_riz>0 & j0==16, c(m rev_riz1 med rev_riz1 freq m taille)

* autres cultures
gen rev_cu1= rev_cu/1000
table j42 if rev_cu>0 & j0==16, c(m rev_cu1 med rev_cu1 freq m taille)
table obs if rev_cu>0 & j0==16, c(m rev_cu1 med rev_cu1 freq m taille)

* elevage
gen revel1 = revel/1000
table j42 if revel>0 & j0==16, c(m revel1 med revel1 freq m taille)
table obs if revel>0 & j0==16, c(m revel1 med revel1 freq m taille)

* peche
gen revpeche1 = revpeche/1000
table j42 if revpeche>0 & j0==16, c(m revpeche1 med revpeche1 freq m taille)
table obs if revpeche>0 & j0==16, c(m revpeche1 med revpeche1 freq m taille)

* AGR
gen activite=revppal+revsec
gen activite1=activite/1000
table j42 if activite>0 & j0==16, c(m activite1 med activite1 freq m taille)
table obs if activite>0 & j0==16, c(m activite1 med activite1 freq m taille)

* structure du revenu

* par commune

gen transrec=transrecmo+transrecnomo
gen rente=rente_riz+rente_cu
gen exploitation = rev_riz+rev_cu+revel + revpeche
* revenus exceptionnels autres que decapitalisation
gen otr_revexcept=revexcept-decap

collapse(sum)activite rev_riz rev_cu revel revpeche exploitation decap otr_revexcept revtot if j0==16, by(j42 year)
gen pr_activite = activite/revtot
gen pr_riz = rev_riz/revtot
gen pr_cu = rev_cu/revtot
gen pr_el = revel/revtot
gen pr_peche = revpeche/revtot
gen pr_decap = decap/revtot
gen pr_otr_revexcept = otr_revexcept/revtot
gen pr_exploitation = exploitation/revtot

table j42, c(m pr_activite m pr_riz m pr_cu m pr_el)
table j42, c(m pr_peche m pr_decap m pr_otr_revexcept)

* par observatoire
use income_2019, clear
merge 1:1 j5 year using menage_2019, nogenerate
gen activite=revppal+revsec
gen transrec=transrecmo+transrecnomo
gen rente=rente_riz+rente_cu
gen otr_revexcept=revexcept-decap
collapse(sum)activite rev_riz rev_cu revel revpeche decap otr_revexcept revtot if j0==16, by(obs year)

gen pr_activite = activite/revtot
gen pr_riz = rev_riz/revtot
gen pr_cu = rev_cu/revtot
gen pr_el = revel/revtot
gen pr_peche = revpeche/revtot
gen pr_decap = decap/revtot
gen pr_otr_revexcept = otr_revexcept/revtot

table obs, c(m pr_activite m pr_riz m pr_cu m pr_el)
table obs, c(m pr_peche m pr_decap m pr_otr_revexcept)
log close




