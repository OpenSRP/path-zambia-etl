-- Truncate the encounter flat table for new extract
TRUNCATE TABLE path_zambia_etl.facility_encounter_report;

-- Initialise facility registration report table with birth registration info
INSERT INTO path_zambia_etl.facility_encounter_report(
encounter_id,
encounter_date,
person_id,
fac_id,
gender,
dob
)
SELECT
encounter_id,
encounter_datetime,
patient_id,
location_id,
openmrs_prod.person.gender,
openmrs_prod.person.birthdate

FROM openmrs_prod.encounter
JOIN openmrs_prod.person  on person_id = openmrs_prod.encounter.patient_id AND openmrs_prod.encounter .encounter_type NOT IN(1,8);

-- provider id
UPDATE
    path_zambia_etl.facility_encounter_report
    INNER JOIN openmrs_prod.encounter_provider  ON path_zambia_etl.facility_encounter_report.encounter_id = openmrs_prod.encounter_provider.encounter_id
SET path_zambia_etl.facility_encounter_report.provider_id = openmrs_prod.encounter_provider.provider_id;

-- Clean up Demo records
DELETE FROM path_zambia_etl.facility_encounter_report WHERE provider_id =1;

-- provider name
UPDATE
    path_zambia_etl.facility_encounter_report
    INNER JOIN openmrs_prod.provider  ON path_zambia_etl.facility_encounter_report.provider_id = openmrs_prod.provider.provider_id
SET path_zambia_etl.facility_encounter_report.provider_name = openmrs_prod.provider.name;

-- Update ZEIR ID child
  UPDATE path_zambia_etl.facility_encounter_report fez,
(   SELECT distinct person_id FROM path_zambia_etl.facility_encounter_report
) fei
SET fez.zeir_id  = (SELECT identifier FROM openmrs_prod.patient_identifier WHERE patient_id = fei.person_id AND patient_identifier.identifier_type =17)
WHERE fez.person_id = fei.person_id;

-- Update ZEIR ID mother
UPDATE path_zambia_etl.facility_encounter_report fem,
  (   SELECT distinct zeir_id  FROM path_zambia_etl.facility_encounter_report
  ) feim
SET fem.mother_id = (SELECT identifier FROM openmrs_prod.patient_identifier WHERE identifier  = concat(feim.zeir_id,"_mother")  AND patient_identifier.identifier_type =18)
WHERE fem.zeir_id = feim.zeir_id;

 -- Update 'HIV exposure
  UPDATE path_zambia_etl.facility_encounter_report cn,
(   SELECT distinct person_id, value_coded
    FROM openmrs_prod.obs WHERE concept_id = 1396
) cnt
SET cn.child_hiv_expo  = (SELECT name FROM openmrs_prod.concept_name WHERE concept_id = cnt.value_coded AND locale = 'en' AND concept_name_type='FULLY_SPECIFIED')
WHERE cn.person_id = cnt.person_id;

-- Update location name
UPDATE
    path_zambia_etl.facility_encounter_report
    INNER JOIN openmrs_prod.location  ON path_zambia_etl.facility_encounter_report.fac_id = openmrs_prod.location.location_id
SET path_zambia_etl.facility_encounter_report.fac_name = openmrs_prod.location.name;

 -- Update facility location for health centres
UPDATE
path_zambia_etl.facility_encounter_report
 INNER JOIN openmrs_prod.location_tag_map ON path_zambia_etl.facility_encounter_report.fac_id = openmrs_prod.location_tag_map.location_id  AND openmrs_prod.location_tag_map.location_tag_id = 4
SET path_zambia_etl.facility_encounter_report.district_id = (SELECT location_id FROM openmrs_prod.location WHERE location_id = (SELECT parent_location FROM openmrs_prod.location WHERE location_id=( path_zambia_etl.facility_encounter_report.fac_id)));

-- Update facility location for zones
UPDATE
path_zambia_etl.facility_encounter_report
 INNER JOIN openmrs_prod.location_tag_map ON path_zambia_etl.facility_encounter_report .fac_id = openmrs_prod.location_tag_map.location_id  AND openmrs_prod.location_tag_map.location_tag_id = 5
SET path_zambia_etl.facility_encounter_report.district_id = (SELECT location_id FROM openmrs_prod.location WHERE location_id =
(SELECT parent_location FROM openmrs_prod.location WHERE location_id=
(SELECT parent_location FROM openmrs_prod.location WHERE location_id=( path_zambia_etl.facility_encounter_report.fac_id))));

 -- Update Province
  UPDATE path_zambia_etl.facility_encounter_report prov,
(   SELECT distinct district_id
    FROM path_zambia_etl.facility_encounter_report
) aprov
SET prov.province_id  = (SELECT location_id FROM openmrs_prod.location WHERE location_id = (SELECT parent_location FROM openmrs_prod.location WHERE location_id=((SELECT location_id FROM openmrs_prod.location WHERE location_id = aprov.district_id ))))
WHERE prov.district_id = aprov.district_id;

-- Update district name
UPDATE
    path_zambia_etl.facility_encounter_report
    INNER JOIN openmrs_prod.location  ON path_zambia_etl.facility_encounter_report.district_id = openmrs_prod.location.location_id
SET path_zambia_etl.facility_encounter_report.district_name = openmrs_prod.location.name;


-- Update province name
UPDATE
    path_zambia_etl.facility_encounter_report
    INNER JOIN openmrs_prod.location  ON path_zambia_etl.facility_encounter_report.province_id = openmrs_prod.location.location_id
SET path_zambia_etl.facility_encounter_report.province_name = openmrs_prod.location.name;

-- Update columns
  UPDATE path_zambia_etl.facility_encounter_report cw,
(   SELECT encounter_id,person_id FROM path_zambia_etl.facility_encounter_report
) cwi
SET
-- Update Weight
cw.child_weight  = (SELECT value_numeric FROM openmrs_prod.obs WHERE encounter_id = cwi.encounter_id AND person_id = cwi.person_id AND concept_id =5089),

-- Update Vaccines
cw.BCG1 = (SELECT if(value_numeric =1,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id = 886  AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.OPV0  = (SELECT if(value_numeric =0,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id =783 AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.OPV1  = (SELECT if(value_numeric =1,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id =783 AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.PCV1  = (SELECT if(value_numeric =1,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id =162342 AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.Penta1  = (SELECT if(value_numeric =1,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id = 1685 AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.Rota1  = (SELECT if(value_numeric =1,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id = 159698 AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.OPV2  = (SELECT if(value_numeric =2,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id = 783 AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.PCV2  = (SELECT if(value_numeric =2,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id = 162342 AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.Penta2  = (SELECT if(value_numeric =2,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id = 1685 AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.Rota2  = (SELECT if(value_numeric =2,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id = 159698 AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.OPV3  = (SELECT if(value_numeric =3,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id = 783 AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.PCV3  = (SELECT if(value_numeric =3,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id = 162342 AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.Penta3  = (SELECT if(value_numeric =3,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id = 1685  AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.Measles1  = (SELECT if(value_numeric =1,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id = 36  AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.MR1  = (SELECT if(value_numeric =1,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id = 162586  AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.OPV4  = (SELECT if(value_numeric =4,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id = 783 AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.Measles2  = (SELECT if(value_numeric =2,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id = 36  AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.MR2  = (SELECT if(value_numeric =2,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id = 162586  AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.BCG2 = (SELECT if(value_numeric =2,1,NULL)  FROM openmrs_prod.obs WHERE obs_group_id in (
SELECT obs_id  FROM openmrs_prod.obs WHERE concept_id = 886  AND encounter_id  =cwi.encounter_id) AND concept_id =1418),

cw.vitamin_a = (SELECT if(value_coded =1065,1,NULL)  FROM openmrs_prod.obs WHERE concept_id = 161534  AND encounter_id = cwi.encounter_id),
cw.mebendezol = (SELECT if(value_coded =1065,1,NULL)  FROM openmrs_prod.obs WHERE concept_id = 159922  AND encounter_id = cwi.encounter_id)

WHERE cw.encounter_id = cwi.encounter_id;

-- Clean up unused encounter rows
DELETE FROM path_zambia_etl.facility_encounter_report WHERE child_weight is NULL AND BCG1 is NULL AND OPV0 is NULL AND OPV1 is NULL AND PCV1 is NULL AND Penta1 is NULL AND Rota1 is NULL AND OPV2 is NULL AND PCV2 is NULL AND Penta2 is NULL AND Rota2 is NULL AND OPV3 is NULL AND PCV3 is NULL AND Penta3 is NULL AND Measles1 is NULL AND MR1 is NULL AND OPV4 is NULL AND Measles2 is NULL AND MR2 is NULL AND BCG2 is NULL AND vitamin_a is NULL AND mebendezol is NULL;

