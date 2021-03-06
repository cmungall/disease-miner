all <-- ['merged.obo','do-all-inversionsT.txt', 'merged.cycles'].

% generic: can be overwritten
'%.obo' <-- '%.owl',
  {\+no_owl('%')},
  'owltools $< -o -f obo --no-check $@'.


% BASIC DO
'doid.owl' <-- [],
  'wget http://purl.obolibrary.org/obo/doid.owl'.
'doid.obo' <-- [],
  'wget http://purl.obolibrary.org/obo/doid.obo'.

% EXPERIMENTAL - we will use this eventually
'omim.tbl' <-- [],
  'wget "http://neuinfo.org/servicesv1/v1/federation/data/nif-0000-03216-7.tsv?includePrimaryData=true" -O $@'.
'omim.json' <-- [],
  'wget "http://neuinfo.org/servicesv1/v1/federation/data/nif-0000-03216-7.json?includePrimaryData=true" -O $@'.

'omim.xml' <-- [],
  'wget "http://neuinfo.org/servicesv1/v1/federation/data/nif-0000-03216-7.xml?includePrimaryData=true" -O $@'.

'omim-id-name.tbl' <-- [],
  'wget http://phenotype-ontologies.googlecode.com/svn/trunk/data/Homo_sapiens/Hs-disease-labels.txt -O $@'.
%%  'blip-findall  -r omim "entity_partition(ID,descriptive)" -select ID -label -use_tabs | sed "s/MIM/OMIM/"  > $@'.

'omim-disease.obo' <-- 'omim-id-name.tbl',
  'util/tbl2omimobo.pl $< > $@'.
'OMIM.obo' <-- 'omim-disease.obo',
  'ln -s $< $@'.


% MAPPING: OMIM<->DO - based on xrefs, which are not necessarily 1:1
% if not 1:1, then OMIM is always a subclass
'omim-doid-equiv.tbl' <-- [],
  'blip-findall -i omim-disease.obo -r disease "one_to_one_xref(D,X,\'OMIM\')" -no_pred -select X-D -label -use_tabs > $@'.
'omim-doid-subclass.tbl' <-- [],
  'blip-findall -i omim-disease.obo -r disease "one_to_many_xref(D,X,\'OMIM\')" -no_pred -select X-D -label -use_tabs > $@'.
'omim-doid-rev-subclass.tbl' <-- [],
  'blip-findall -i omim-disease.obo -r disease "many_to_one_xref(D,X,\'OMIM\')" -no_pred -select X-D -label -use_tabs > $@'.
'omim-doid-m2m.tbl' <-- [],
  'blip-findall -i omim-disease.obo -r disease "many_to_many_xref(D,X,\'OMIM\')" -no_pred -select X-D -label > $@'.
%'omim-doid-o2m.tbl' <-- [],
%  'blip-findall -i omim-disease.obo -r disease "many_to_one_xref(D,X,\'OMIM\')" -no_pred -select X-D -label > $@'.

'%.ids' <-- ['%'],
  'cut -f1,3 $< > $@'.

'omim-doid-equiv.owl' <-- 'omim-doid-equiv.tbl.ids',
  'owltools --create-ontology doid/extensions/$@ --parse-tsv -a EquivalentClasses $< -o $@'.
'omim-doid-subclass.owl' <-- 'omim-doid-subclass.tbl.ids',
  'owltools --create-ontology doid/extensions/$@ --parse-tsv -a SubClassOf $< -o $@ '.
'omim-doid-rev-subclass.owl' <-- 'omim-doid-subclass.tbl.ids',
  'owltools --create-ontology doid/extensions/$@ --parse-tsv -s -a SubClassOf $< -o $@ '.

'doid-no-omim-xref.obo' <-- 'doid.obo',
  'grep -v "^xref: OMIM" $< > $@'.

% Combine into a single OWL bridge file. This may include equivalence pairs
'do-omim-combined.owl' <-- ['doid-no-omim-xref.obo', 'omim-doid-subclass.owl', 'omim-doid-rev-subclass.owl', 'omim-doid-equiv.owl', 'omim-disease.obo'],
  'owltools --use-catalog $< omim-doid-subclass.owl omim-doid-equiv.owl omim-disease.obo --merge-support-ontologies --reasoner elk --assert-inferred-subclass-axioms --allowEquivalencies -o $@'.

% Merge bridge + DO + OMIM
%'do-omim-merged.owl' <-- 'do-omim-combined.owl',
%  'owltools $< --merge-equivalent-classes -sa -f DOID -t OMIM -o $@ -o -f obo --no-check do-omim-merged.obo'.


'%-inversions.txt' <-- ['%.obo'],
  'blip-findall -i $< "class_quad_flip(C1,P1,C2,P2,\'OMIM\')" -no_pred -label -use_tabs > $@'.
'%-inversionsT.txt' <-- ['%.obo'],
  'blip-findall -i $< "class_quad_flipT(C1,P1,C2,P2,\'OMIM\')" -no_pred -label -use_tabs > $@'.

% ----------------------------------------
% -- EXPERIMENTAL --

% fetch basic EFO
'efo-disease.obo' <-- [],
  'blip ontol-query -r efo -query "class(X,disease),subclassRT(ID,X)" -to obo > $@.tmp && util/fix-efo.pl $@.tmp > $@'.

no_owl(orphanet).
'orphanet.owl' <-- ['efo-disease.obo'],
  'owltools $< --extract-subset orphanet --remove-dangling-axioms --set-ontology-id http://purl.obolibrary.org/obo/orphanet.owl -o $@'.


% generic: generation of equivs and subclasses from xrefs
'$Ext-$Src-equiv.tbl' <-- ['$Src.obo'],
  'blip-findall -i $< "one_to_one_xref(D,X,\'$Ext\')" -no_pred -select X-D > $@'.
'$Ext-$Src-subclass.tbl' <-- ['$Src.obo'],
  'blip-findall -i $< "entity_xref_idspace(D,X,\'$Ext\'),\\+ one_to_one_xref(D,X,\'$Ext\')" -no_pred -select X-D > $@'.

'%-equiv.owl' <-- '%-equiv.tbl',
  'owltools --create-ontology doid/extensions/$@ --parse-tsv -a EquivalentClasses $< -o $@ '.
'%-subclass.owl' <-- '%-subclass.tbl',
  'owltools --create-ontology doid/extensions/$@ --parse-tsv -a SubClassOf $< -o $@ '.
'%-mappings.owl' <-- ['%-subclass.owl','%-equiv.owl'],
  'owltools --create-ontology doid/extensions/$@ %-subclass.owl %-equiv.owl --merge-support-ontologies -o $@'.
'$Ext-$Src-flips.txt' <-- ['$Ext-$Src-mappings.obo'],
  'blip-findall -i $< -i $Src.obo -i $Ext.obo "class_quad_flip(C1,P1,C2,P2)" -no_pred -label -use_tabs > $@'.

'%-mappings-merged.owl' <-- ['%-mappings.owl'],
  'owltools $< --run-reasoner -r elk --merge-equivalence-sets -o $@ > $@.LOG'.

'align_doid_efo.tbl' <-- ['efo-disease.obo'],
  'blip-findall -i $< -r disease  -consult util/aligner.pro efo/2 -label -use_tabs > $@.tmp && sort -u $@.tmp > $@'.

'align_doid_efo-cut.tbl' <-- 'align_doid_efo.tbl',
  'cut -f3,5 $< > $@'.

'doid-equiv-efo.owl' <-- 'align_doid_efo-cut.tbl',
  'owltools --create-ontology doid/extensions/$@ --parse-tsv -a EquivalentClasses $< -o $@ '.

'align_doid_orphanet.tbl' <-- ['orphanet.obo'],
  'blip-findall -i $< -r disease  -consult util/aligner.pro orphanet/2 -label -use_tabs > $@.tmp && sort -u $@.tmp > $@'.

'align_doid_orphanet-cut.tbl' <-- 'align_doid_orphanet.tbl',
  'cut -f3,5 $< > $@'.

'doid-equiv-orphanet.owl' <-- 'align_doid_orphanet-cut.tbl',
  'owltools --create-ontology doid/extensions/$@ --parse-tsv -a EquivalentClasses $< -o $@ '.

'align_doid_wp.tbl' <-- 'dbpedia/dbpo-Disease.obo',
  'blip-findall -u metadata_nlp -i $< -i dbpedia/dcat-auto.obo -r disease -goal index_entity_pair_label_match  "entity_pair_label_reciprocal_best_intermatch(T1,T2,St)" -label -use_tabs > $@.tmp && sort -u $@.tmp > $@'.

% merges DO, OMIM and ORPHANET (not full EF)
% requires bridge axioms
'do-all-unmerged-NR.owl' <-- ['doid.owl', 'omim-doid-subclass.owl', 'omim-doid-equiv.owl', 'omim-disease.obo', 'OMIM-orphanet-equiv.owl', 'OMIM-orphanet-subclass.owl', 'orphanet.obo', 'doid-equiv-orphanet.owl'],
  'owltools --use-catalog doid.owl omim-doid-subclass.owl omim-doid-equiv.owl omim-disease.obo OMIM-orphanet-equiv.owl OMIM-orphanet-subclass.owl orphanet.obo doid-equiv-orphanet.owl --merge-support-ontologies -o $@'.

% COMBINE (but do not merge classes) DO, EFO and OMIM with respective bridges
% note there will be a number of 'duplicates', linked by equiv classes axioms
'do-allTEST-unmerged-NR.owl' <-- ['doid.owl', 'omim-doid-subclass.owl', 'omim-doid-equiv.owl', 'omim-disease.obo', 'OMIM-efo-disease-equiv.owl', 'OMIM-efo-disease-subclass.owl', 'efo-disease.obo', 'doid-equiv-efo.owl'],
  'owltools --use-catalog doid.owl omim-doid-subclass.owl omim-doid-equiv.owl omim-disease.obo OMIM-efo-disease-equiv.owl OMIM-efo-disease-subclass.owl efo-disease.obo doid-equiv-efo.owl --merge-support-ontologies -o $@'.


% reasoned version of unmerged-NR
'do-all-unmerged.owl' <-- 'do-all-unmerged-NR.owl',
  'owltools $< --reasoner elk --assert-inferred-subclass-axioms --removeRedundant --allowEquivalencies -o $@'.

% ^^ use this in input to merged.owl when done

% END OF EXPERIMENTAL
% ----------------------------------------


% MERGE. Prioritize OMIM IDs but favor DO labels
% in step 2, leave original labels
'merged-1.owl' <-- ['do-omim-combined.owl'],
  'owltools $< --reasoner elk --merge-equivalence-sets -s OMIM 9 -s DOID 8 -s ORPHANET 7 -s EFO 6 -l DOID 9 -l ORPHANET 7 -d DOID 9 --assert-inferred-subclass-axioms  --removeRedundant --set-ontology-id http://purl.obolibrary.org/obo/upheno/doid/merged.owl -o $@ >& $@.LOG'.
'merged-1.obo' <-- ['merged-1.owl'],
  'owltools $< -o -f obo --no-check $@.tmp && grep -v ^owl-axioms: $@.tmp | perl -npe "s/^equivalent_to:/xref:/" > $@'.

'merged.obo' <-- ['merged-1.obo', 'disease-pw-xref.obo'],
  'obo-merge-tags.pl -t xref $<  disease-kegg-xref.obo > $@'.

'merged-with-ECAs.obo' <-- 'merged.obo',
  'perl -npe "s@^xref:@equivalent_to:@ if m@xref: (DOID)@" $< > $@.tmp && mv $@.tmp $@'.
'merged.owl' <-- ['merged-with-ECAs.obo', 'disease-kegg-depictions.omn'],
  'owltools $< disease-kegg-depictions.omn --merge-support-ontologies --set-ontology-id http://purl.obolibrary.org/obo/upheno/doid/merged.owl -o $@'.



'%.cycles' <-- ['%.obo'],
  'blip-findall -i $< subclass_cycle/2 > $@'.

% deploy to phenotype-ontologies
deploy <-- ['merged.obo'],
  'cp merged.* doid/'.
publish <-- ['merged.obo'],
  'cp merged.* doid/ && cd doid && svn commit -m "new release"'.

% ----------------------------------------
% PW
% ----------------------------------------
'pw.obo' <-- [],
  'wget ftp://rgd.mcw.edu/pub/data_release/ontology_obo_files/pathway/pathway.obo -O $@'.

'disease-pw.obo' <-- 'pw.obo',
  'blip ontol-subset -i $< -id PW:0000013 -down 20 -to obo > $@.tmp && mv $@.tmp $@'.

'disease-pw-align.txt' <-- ['disease-pw.obo','merged-1.obo'],
  'blip-findall -u metadata_nlp -debug index -i $< -i merged-1.obo -i util/ignore_word_disease_pw.pro  -consult util/pwaligner.pro m/2 -label -use_tabs -no_pred > $@.tmp && sort -u $@.tmp > $@'.

'disease-pw-xref.obo' <-- 'disease-pw-align.txt',
  'tbl2obolinks.pl -r xref $< > $@'.

'disease-kegg-links.txt' <-- 'disease-pw-xref.obo',
  'blip-findall -i $< -i merged-1.obo -i disease-pw.obo "entity_xref(D,P),entity_synonym(P,S),class(D,DN),class(P,PN)" -select "x(D,DN,S,PN)" -no_pred | sort -u | grep KEGG > $@'.

'disease-kegg-xref.obo' <-- 'disease-kegg-links.txt',
  'tbl2obolinks.pl -r xref $< > $@'.

'doid-kegg-links.txt' <-- 'disease-pw-xref.obo',
  'blip-findall -i $< -i merged-1.obo -i disease-pw.obo "entity_xref(MD,P),entity_synonym(P,S),(entity_xref(MD,D);D=MD),class(MD,DN),class(P,PN)" -select "x(D,DN,S,PN)" -no_pred | grep KEGG | grep DOID | sort -u > $@'.

'doid-kegg-xref.obo' <-- 'doid-kegg-links.txt',
  'tbl2obolinks.pl -r xref $< > $@'.

'disease-kegg-depictions.omn' <-- 'disease-kegg-links.txt',
  './util/mk-depictions-kegg.pl $< > $@'.



%ftp://rgd.mcw.edu/pub/data_release/ontology_obo_files/pathway/pathway.obo

% #DiseaseName	SourceName	ConceptID	SourceID	DiseaseMIM	LastModified
'clinvar-disease-names.tbl' <-- [],
  'wget ftp://ftp.ncbi.nlm.nih.gov/pub/clinvar/disease_names -O $@'.


'do-defs.tab' <-- [],
  'blip-findall -r disease "class(X,N),def(X,D)" -select "x(X,N,D)" -no_pred > $@'.

'dict.txt' <-- [],
  'blip-findall -r uberonp -r CL "class(ID,N)" -select N > $@'.

'run.out' <-- ['dict.txt', 'do-defs.tab'],
  './d-runner.pl -a -d dict.txt do-defs.tab > $@'.

'do-rels.txt' <-- 'run.out',
  './parse-results.pl -a do-defs.tab "ann/DOID_*/*" > $@'.

'do-rels-m.pro' <-- 'do-rels.txt',
  'blip-findall -consult util/map_dorel.pro -r fma3 -r uberonp -i $< -f "tbl(dorel)" mdorel/6 -write_prolog > $@'.

'do-rels-nr.txt' <-- 'do-rels-m.pro',
  'blip-findall  -table_pred subclassRT/2 -debug nr -r disease -consult util/nr_dorel.pro -r uberonp -i $<  nrdorel/6 -no_pred > $@.tmp && sort -u $@.tmp > $@'.
%  'blip-findall -debug index -index "ontol_db:subclassRT(1,1)" -debug nr -r disease -consult util/nr_dorel.pro -r uberonp -i $<  nrdorel/6 -no_pred > $@.tmp && sort -u $@.tmp > $@'.

'do-rels-nr.pro'  <-- 'do-rels-nr.txt',
  'tbl2p -p dorel $< > $@'.


'summary.txt' <-- 'do-rels-nr.txt',
  'perl -npe "s/:/\t/g" $<  | count-occ-group.pl 5 > $@'.


/*
'termlists' <-- ['do-rels-nr.pro'|Deps],
  {consult('do-rels-nr.pro'),
   setof([termlist,-,DB,'.txt'],
         (   dorel(D,DN,R,X,XN,Def
   }
  */

'summary2.txt' <-- 'do-rels-nr.pro',
  'blip-findall -f dorel -i $< "aggregate(count,DB,(dorel(D,DN,R,X,XN,Def),id_idspace(X,DB)),,id_idspace(X,\'$DB\')" -select X-XN -no_pred | sort -u > $@'.

'termlist-$DB.txt' <-- 'do-rels-nr.pro',
  'blip-findall -f dorel -i $< "dorel(D,DN,R,X,XN,Def),id_idspace(X,\'$DB\')" -select X-XN -no_pred | sort -u > $@'.


relmap(defgenus,is_a,'DOID').
relmap(results_in,results_in,'HP').
relmap(_,has_locus,'UBERON').
relmap(_,has_locus,'CL').
relmap(has_symptom,has_symptom,'SYMP').
relmap(_,has_phenotype,'MP').
relmap(_,has_phenotype,'HP').
relmap(transmitted_by,transmitted_by,'UBERON').
relmap(transmitted_by,transmitted_by,'TRANS').
relmap(transmitted_by,transmitted_by,'NCBITaxon').
relmap(has_material_basis,has_material_basis,'SYMP').
relmap(has_material_basis,has_material_basis,'NCBITaxon').
relmap(has_material_basis,has_material_basis,'GO').
relmap(has_material_basis,has_material_basis,'CL').
relmap(has_material_basis,has_material_basis,'UBERON').
relmap(caused,has_material_basis,'NCBITaxon').

        

'bridges' <-- Deps,
{findall(t(['do-bridge-',R,'-',NS,'.obo']),
         relmap(_,R,NS),
         Deps)},
   'touch $@'.


'do-bridge-$Rel-$NS.obo' <-- ['do-rels-nr.txt'],
  {relmap(RelIn,Rel,NS),(var(RelIn)->RelIn='.';true)},
  './tab-to-obo.pl $RelIn $Rel $NS $< > $@'.

% TODO
'do-x-$NS.obo' <-- Deps,
{findall(t(['do-bridge-',R,'-',NS,'.obo']),
         relmap(_,R,NS),
         Deps),
 findall(A,(member(t(L),Deps),concat_atom(L,A)),As),
 concat_atom(As,' ',DepsA)},
   'cat $DepsA > $@'.

'NCBITaxon_import.owl' <-- 'do-x-NCBITaxon.obo',
  'owltools $< http://purl.obolibrary.org/obo/ncbitaxon/subsets/taxslim.owl --add-imports-from-supports --extract-module -c -s http://purl.obolibrary.org/obo/ncbitaxon/subsets/taxslim.obo --extract-mingraph --set-ontology-id http://purl.obolibrary.org/obo/doid/extensions/import_NCBITaxon.owl -o $@ '.

'$NS_import.owl' <-- 'do-x-$NS.obo',
  {downcase_atom(NS,NS_dn)},
  'owltools $< http://purl.obolibrary.org/obo/$NS_dn.owl --add-imports-from-supports --extract-module -c -s http://purl.obolibrary.org/obo/$NS_dn.owl --extract-mingraph --set-ontology-id http://purl.obolibrary.org/obo/doid/extensions/$NS_import.owl -o.owl $@ '.




'do-idn.obo' <-- [],
  'blip ontol-query -r disease -query "class(ID)" -to obo | obo-filter-tags.pl -t id -t name -t def > $@'.


all <-- 'all-do-bridge.obo'.

'do-merged.obo' <-- ['do-idn.obo', bridges],
  'obo-merge-tags.pl -t id  -t is_a -t relationship $< do-bridge-*obo > $@'.

'all-do-bridge.obo' <-- bridges,
  'obo-merge-tags.pl -t id  -t is_a -t relationship -t intersection_of do-bridge-*obo > $@'.

'do-plus-axioms.owl' <-- 'all-do-bridge.obo',
  'owltools $< -o $@'.


% OBOL
