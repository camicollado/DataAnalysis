/* Cantidad de Registros: */
select COUNT(*)
from dataset_covid
-- 4,306,456

-- PROBLEMAS
-- Cuando lo habiamos subido como date la primera vez pasaba esto.
select fecha_ingreso, COUNT(*)
from dataset_covid_147
where EXTRACT(day from fecha_ingreso) >= 13 -- NO EXISTENE FECHAS CON DIAS MAYORES A 12
		-- Resuelto

select distinct categoria 
from dataset_covid
where categoria like 'EMPADRONAM%'
order by categoria
		-- Resuelto

select fecha_ingreso_n, fecha_cierre_contacto_n 
from dataset_covid
where fecha_cierre_contacto_n < fecha_ingreso_n
		-- Resuelto

select distinct Lat, Long, barrio_n
from dataset_covid
where (Lat >= 0 or Long >= 0)
		-- Resuelto


/* Normalizacion Fechas: al importar la base de datos nos dimos cuenta que se ajustaban mal las fechas, solo aparecian las fechas con dias del 1 al 12,
 por eso importalmos las fechas como varchar y luego las normalizamos con la funcion to_timestamp. */ 

-- imprimimos las fechas como vienen para saber su formato
select fecha_ingreso, fecha_cierre_contacto
from dataset_covid
-- Formato de fecha: DD/MM/YYYY HH24:MI:SS

-- imprimimos las fechas actualizadas con la funcion to_timestamp con la fecha anterior para ver si se hizo correctamente.
select to_timestamp(fecha_ingreso, 'DD/MM/YYYY HH24:MI:SS')::TIMESTAMP  , fecha_ingreso
from dataset_covid 

-- creamos la variable fecha_ingreso_n la cual normalizaremos.
alter table dataset_covid 
add column fecha_ingreso_n timestamp

-- actualizamos la nueva variable con formato timestamp.
update dataset_covid 
set fecha_ingreso_n = to_timestamp(fecha_ingreso, 'DD/MM/YYYY HH24:MI:SS')::TIMESTAMP

-- repetimos el proceso para la variable fecha_cierre_contacto.
alter table dataset_covid 
add column fecha_cierre_contacto_n timestamp

update dataset_covid 
set fecha_cierre_contacto_n = to_timestamp(fecha_cierre_contacto , 'DD/MM/YYYY HH24:MI:SS')::TIMESTAMP

-- Normalizamos las fechas donde el cierre era menor al ingreso intercambiando sus valores:
update dataset_covid 
set fecha_ingreso_n = fecha_cierre_contacto_n
where fecha_cierre_contacto_n < fecha_ingreso_n

update dataset_covid 
set fecha_cierre_contacto_n = to_timestamp(fecha_ingreso, 'DD/MM/YYYY HH24:MI:SS')::TIMESTAMP
where fecha_cierre_contacto_n = fecha_ingreso_n 

/* Normalizacion Barrios y Comunas: muchos barrios estan vacios y muchas comunas tienen datos de barrios.*/

-- Visualizamos los existentes.
select distinct comuna, barrio
from dataset_covid

-- Creamos la variable del barrio que vamos a normalizar.
alter table dataset_covid 
add column barrio_n varchar(1000)

-- Cargamos la variable con los barrios existentes en mayuscula.
update dataset_covid 
set barrio_n = upper(btrim(barrio))

-- Cargamos la variable en los lugares donde esta vacia con los valores de la comuna.
update dataset_covid 
set barrio_n = upper(btrim(comuna))
where barrio_n like '' or barrio_n like NULL

-- Sacamos de la variable los valores que tienen datos de la comuna.
update dataset_covid 
set barrio_n = null
where barrio_n like '%comuna%' or barrio_n like '%COMUNA%'

-- Visualizamos los resultados.
select barrio, barrio_n, comuna
from dataset_covid dc 

-- Encontramos muchos barrios donde se les inserto un punto, guiones o simbolos no redundantes
select distinct barrio_n
from dataset_covid dc 
where (barrio_n like '.%' or barrio_n like '-%' or barrio_n like '0%' or barrio_n like ' %' or barrio_n like ',%') 
and (barrio_n not like '%MON%' and barrio_n not like '%LUG%' and barrio_n not like '%ATA%')

-- Normalizamos todos esos registros que encontramos.
update dataset_covid 
set barrio_n = null
where barrio_n in (select distinct barrio_n
from dataset_covid dc 
where (barrio_n like '.%' or barrio_n like '-%' or barrio_n like '0%' or barrio_n like ' %' or barrio_n like ',%') 
and (barrio_n not like '%MON%' and barrio_n not like '%LUG%' and barrio_n not like '%ATA%')) -- habia 315 registros asi.

-- Estos barrios tenian un simbolo adelante.
select distinct barrio_n
from dataset_covid dc 
where (barrio_n like '.%' or barrio_n like '-%' or barrio_n like '0%' or barrio_n like ' %' or barrio_n like ',%') 
-- Ej: ,ATADEROS, .LUGANO, 

-- Normalizamos sacandole el primer caracter.
update dataset_covid 
set barrio_n = substr(barrio_n,2,length(barrio_n))
where barrio_n in(select distinct barrio_n
from dataset_covid dc 
where (barrio_n like '.%' or barrio_n like '-%' or barrio_n like '0%' or barrio_n like ' %' or barrio_n like ',%')) -- habia 23 registros asi.

-- Normalizamos sacando los registros que tienen dos espacios.
select distinct barrio_n
from dataset_covid dc 
where barrio_n like '%  %'

update dataset_covid 
set barrio_n = replace(barrio_n,'  ',' ')

-- Muchos de los barrios tienen siglas de 3 digitos, analizandolas entendimos que eran una parte del codigo postal.
select distinct barrio_n
from dataset_covid
where length(barrio_n) = 3

-- Al ser tan dificil identificarlas decidimos eliminarlas.
update dataset_covid 
set barrio_n = null
where barrio_n in (select distinct barrio_n
from dataset_covid
where length(barrio_n) = 3) -- hay 1071353 registros asi.

-- Encontramos problemas con los registros de Caballito.
select distinct barrio_n
from dataset_covid
where barrio_n like '%CABAL%'
-- Todas las formas que escribieron Caballito: CABALLITI, ALMAGRO CABALLITO,CABALLITOO, CABALLITS, CABALLITOVILLA DEL PARQUE, CABALLA, CABALLITO., CABALLITO OESTE, CABALALLITO, CABALLILTA, CABALLATI, CABALLITOQ, CABALLOITO
-- CABALLITOSS, CABALLAITO, CABALLIITO, CABALLLITO, CABALLITP, CABALLI, CABALLIDO, CABALLO, CABALLIO, CABALLITIO, CABALIITO, CABALLTO, CABALLITO-FLORES, CABALLITPO, CABALLITA, CABALITO, CABALLITOS, CABALLIATO, CABALLITO, PATERNAL Y CABALLITO, CABALLITO NORTE
-- :(

-- Normalizamos los que encontramos en la consulta anterior.
update dataset_covid 
set barrio_n = 'CABALLITO'
where barrio_n in (select distinct barrio_n
from dataset_covid
where barrio_n like '%CABAL%') -- habia 138065 registros de distintos caballito.

-- Encontramos problemas con los registros de Nuñez.
select distinct barrio_n
from dataset_covid
where (barrio_n like '%EZ' or barrio_n like '%ES') and (barrio_n like 'N%' or barrio_n like 'ñ%')
-- Todas las formas que escribieron Nuñez: NEñEZ, NIñEZ, NUEZ, NUEÑEZ, NUEñEZ, NUNEZ, NUNñEZ, NUÑEZ, NUñEZ, NUñIEZ, NÚÑEZ, NúNEZ, NúÑEZ, NúñEZ, ñUNEZ, ñUñEZ
-- :(

-- Normalizamos los que encontramos en la consulta anterior.
update dataset_covid 
set barrio_n = 'NUÑEZ'
where barrio_n in (select distinct barrio_n
from dataset_covid
where (barrio_n like '%EZ' or barrio_n like '%ES') and (barrio_n like 'N%' or barrio_n like 'ñ%')) -- habia 40005 registros de distintos nuñez.

-- Encontramos problemas con los registros de Constitucion.
select distinct barrio_n
from dataset_covid
where barrio_n like '%CONS%' and barrio_n not like '%VILLA%'
-- Todas las formas que escribieron Constitucion: BARRIO CONSTITUCIóN, CONS, CONSETITUCION, CONSITITUCION, CONSITUCION, CONSITUTICION, CONSTANTINE, CONSTINTUCIO, CONSTITUACION
-- CONSTITUCIOM, CONSTITUCION, CONSTITUCION., CONSTITUCION/BARRACAS, CONSTITUCIÒN, CONSTITUCIÓN, CONSTITUCIòN, CONSTITUCIóN, CONSTITUCIóN., CONSTITUCUóN, CONSTITUCíIóN
-- CONSTITUICON, CONSTITUTICóN, CONSTIUCION, CONSTOTUCION

-- Normalizamos los que encontramos en la consulta anterior.
update dataset_covid 
set barrio_n = 'CONSTITUCION'
where barrio_n in (select distinct barrio_n
from dataset_covid
where barrio_n like '%CONS%' and barrio_n not like '%VILLA%') -- habia 25188 registros de distintos caballito.

-- Deberiamos hacerlo para el resto... se encuentran muchos casos asi.

-- Descargamos la tabla del distinct del barrio_n para normalizarla con open_refine y despues la volvemos a traer al programa y normalizamos.
select distinct barrio_n
from dataset_covid

-- Hicimos una consulta de los barrios_n que quedaron para seguir normalizandolos fuera de Postgres. 
-- Exportamos la consulta a un csv que normalizamos usando OpenRefine y detalles finales con Excel.

select distinct barrio_normalizado from barrio_normalizado_csv bnc order by barrio_normalizado

-- Copiamos los datos que normalizamos en la variable barrio_n
update dataset_covid 
set barrio_n = replace(dataset_covid.barrio_n, dataset_covid.barrio_n,b.barrio_normalizado) 
from barrio_normalizado_csv b
where dataset_covid.barrio_n = b.barrio_n -- habia 2450576 registros asi.

-- Como vimos que seguia habiendo muchos barrios distintos volvimos a repetir el proceso.
select distinct barrio_normalizado from barrio_normalizado_csv bnc order by barrio_normalizado

-- Copiamos los datos que normalizamos en la variable barrio_n
update dataset_covid 
set barrio_n = replace(dataset_covid.barrio_n, dataset_covid.barrio_n,upper(btrim(b.barrio_n1)))
from barrio_n2_csv b
where dataset_covid.barrio_n = b.barrio_n -- habia 2445128 por normalizar.

-- Asi pudimos pasar de 12905 barrios distintos a solo 804! :)
select count(distinct barrio) as Cantidad_Barrios, count(distinct barrio_n) as Cantidad_Barrios_Normalizados 
from dataset_covid dc 

-- Tambien creamos una nueva variable por provincia. Y la cargamos:
alter table dataset_covid 
add column provincia varchar(1000)

update dataset_covid 
set provincia = upper(btrim(c.barrio_general))
from barrio_n2_csv c
where dataset_covid.barrio_n = c.barrio_n1  

update dataset_covid 
set provincia = 'NO IDENTIFICADO'
where provincia is null -- habia 1101418 registros asi.

update dataset_covid 
set provincia = 'SANTA FE'
where provincia like '%FE%' 

-- Pasamos a normalizar utilizando la base de comuna y barrio.
-- Normalizamos Nuñez porque no encuentra la ñ.
update comunas_y_barrios_csv 
set barrio = 'NUÑEZ'
where barrio like 'NU%' and barrio like '%EZ'

-- Normalizamos Velez Sarfield porque no encontraba el tilde. (El resto lo habia cambiado en la base original.)
update comunas_y_barrios_csv 
set barrio = 'VELEZ SARSFIELD'
where barrio like 'V%' and barrio like '%LEZ SARSFIELD'

-- Encontramos cuales son los barrios que coinciden en el data set.
select distinct dc.barrio_n, c.barrio, dc.comuna, c.comuna
from dataset_covid dc
join comunas_y_barrios_csv c on dc.barrio_n = c.barrio 
where dc.barrio_n != '' and dc.barrio_n is not null

-- Creamos la variable comuna_n que normalizaremos.
alter table dataset_covid 
add column comuna_n varchar(1000)

-- Copiamos segun los datos de comuna a la nueva variable sobre la que normalizaremos.
update dataset_covid
set comuna_n = 'Sin identificar'

-- Copiamos los datos que existen en la base ya normalizada.
update dataset_covid 
set comuna_n = replace(comuna_n, comuna_n,c.comuna) 
from comunas_y_barrios_csv c
where barrio_n = c.barrio and barrio_n != '' and barrio_n is not null 


/* Normalizamos Latitud y Longitud: */
-- Como identificamos que hay llamadas del exterior no seria un problema que la latitud o la longitud sea positiva. 
-- Eliminamos todas las latitudes y longitudes que sean positivas en el caso de que la provincia sea distinta de 'EXTERIOR'
update dataset_covid 
set lat = null
where concat(lat, long) in (select distinct concat(lat, long)
from dataset_covid
where (Lat >= 0 or Long >= 0) and provincia != 'EXTERIOR')

update dataset_covid 
set long = null
where concat(lat, long) in (select distinct concat(lat, long)
from dataset_covid
where (Lat >= 0 or Long >= 0) and provincia != 'EXTERIOR')

-- Eliminamos la latitud y longitud de las que estan en 0.

update dataset_covid 
set long = null
where (Lat = 0 or Long = 0)

select count(*) from dataset_covid dc 
select count(*)
from (select distinct contacto, periodo, fecha_ingreso, fecha_cierre_contacto, barrio, categoria, long, lat, fecha_ingreso_n, fecha_cierre_contacto_n from dataset_covid dc2) as df

select count(*)
from (select distinct contacto, periodo, categoria, fecha_ingreso, comuna, barrio, domicilio_calle, domicilio_altura, lat, long, canal, estado_del_contacto, fecha_cierre_contacto, detalle_reclamo
from dataset_covid dc ) as df

/* Normalizamos Categorias: */
-- Las pasamos todas a mayuscula.
update dataset_covid 
set categoria = upper(categoria)

-- Creamos la variable categoria_n sobre la cual vamos a normalizar.
alter table dataset_covid 
add column categoria_n varchar(1000)

-- Le copiamos los datos actuales de la tabla categoria borrandole los espacios al inicio y al final.
update dataset_covid 
set categoria_n = btrim(categoria)

-- Seleccionamos todas las categorias que inician con un numero.
select distinct categoria_n
from dataset_covid dc 
where left(categoria_n, 1) in ('1','2','3','4','5','6','7','8','9','0')

-- Eliminamos el numero el espacio y el guion de estas categorias.
update dataset_covid 
set categoria_n = substr(categoria_n,5,length(categoria_n))
where categoria_n in (select distinct categoria_n
from dataset_covid dc 
where left(categoria_n, 1) in ('1','2','3','4','5','6','7','8','9','0')) -- habia 825761 registros asi.

-- Eliminamos categorias que no dicen nada como 'ACTIVAMENTE' o 'AMBAS'
update dataset_covid 
set categoria_n = null
where categoria_n in ('',' ','ACTIVAMENTE','AMBAS')

-- Juntamos la categoria 'ASISTENCIA SOCIAL URGENTE'
select distinct categoria_n
from dataset_covid dc 
where categoria_n like 'ASISTENCIA SOCIAL U%' -- hay 2 categorias.

update dataset_covid 
set categoria_n = 'ASISTENCIA SOCIAL URGENTE'
where categoria_n in (select distinct categoria_n
from dataset_covid dc 
where categoria_n like 'ASISTENCIA SOCIAL U%')

-- Unimos en una categoria todas las que tengan 'GESTION DE TURNOS - VACUNACIóN COVID-19%'
select distinct categoria_n
from dataset_covid dc
where categoria_n like 'GESTION DE TURNOS - VACUNACIóN COVID-19%'

update dataset_covid 
set categoria_n = 'GESTION DE TURNOS - VACUNACIóN COVID-19'
where categoria_n in (select distinct categoria_n
from dataset_covid dc
where categoria_n like 'GESTION DE TURNOS - VACUNACIóN COVID-19%') -- hay 334361 registros asi.

-- Como las categorias de empadronamiento se superponen entre si decidimos englobarlas todas en la categoria 'EMPADRONAMIENTO VACUNA COVID-19'
select distinct categoria_n
from dataset_covid dc
where categoria_n like '%EMPADR%' and categoria_n not like '%DOMICILIO%'

update dataset_covid 
set categoria_n = 'EMPADRONAMIENTO VACUNA COVID-19'
where categoria_n in (select distinct categoria_n
from dataset_covid dc
where categoria_n like '%EMPADR%' and categoria_n not like '%DOMICILIO%') -- hay 430194 registros asi

-- Repetimos lo mismo para el empadronamiento a domicilio armando la categoria 'EMPADRONAMIENTO VACUNA COVID-19 A DOMICILIO'
select distinct categoria_n
from dataset_covid dc
where categoria_n like '%DOMIC%'

update dataset_covid 
set categoria_n = 'EMPADRONAMIENTO VACUNA COVID-19 A DOMICILIO'
where categoria_n in (select distinct categoria_n
from dataset_covid dc
where categoria_n like '%DOMIC%') -- hay 65729 registros asi.

-- Y lo mismo para 'VACUNACION COVID-19'
select distinct categoria_n
from dataset_covid dc 
where categoria_n like 'VACUNA%'

update dataset_covid 
set categoria_n = 'VACUNACION COVID-19'
where categoria_n in (select distinct categoria_n
from dataset_covid dc 
where categoria_n like 'VACUNA%') -- hay 1304954 registros asi.

-- 'VALIDACION DE SUPUESTO VOLUNTARIO'
select distinct categoria_n
from dataset_covid dc 
where categoria_n like 'VALIDAC%'

update dataset_covid 
set categoria_n = 'VALIDACION DE SUPUESTO VOLUNTARIO'
where categoria_n in (select distinct categoria_n
from dataset_covid dc 
where categoria_n like 'VALIDAC%')

-- INFORMACION
select distinct categoria_n
from dataset_covid dc 
where categoria_n like 'INFORMA%'

update dataset_covid 
set categoria_n = 'INFORMACION'
where categoria_n in (select distinct categoria_n
from dataset_covid dc 
where categoria_n like 'INFORMA%') -- hay 160466 registros asi.

-- 'BAJA AL PROGRAMA'
select distinct categoria_n
from dataset_covid dc 
where categoria_n like '%BAJA%' and categoria_n not like '%VOLUNTARIO%'

update dataset_covid 
set categoria_n = 'BAJA AL PROGRAMA'
where categoria_n in (select distinct categoria_n
from dataset_covid dc 
where categoria_n like '%BAJA%' and categoria_n not like '%VOLUNTARIO%')

-- Eliminamos las categorias que tienen pocos registros
select categoria_n, count(*)
from dataset_covid dc 
group by categoria_n
having count(*) <=3

update dataset_covid 
set categoria_n = null
where categoria_n in (select categoria_n
from dataset_covid dc 
group by categoria_n
having count(*) <=3)

-- PROBLEMAS CON VOLUNTARIO
select distinct categoria_n
from dataset_covid dc 
where categoria_n like 'PROBLEMAS CON VOLUN%' or categoria_n like 'SOLICITA CAMBIO DE VOLUNTARIO.' or categoria_n like 'EL VOLUNTARIO NO SE COMUNICA' or categoria_n like 'INCUMPLIMIENTO DEL VOLUNTARIO'

update dataset_covid 
set categoria_n = 'PROBLEMAS CON VOLUNTARIO'
where categoria_n in (select distinct categoria_n
from dataset_covid dc 
where categoria_n like 'PROBLEMAS CON VOLUN%' or categoria_n like 'SOLICITA CAMBIO DE VOLUNTARIO.' or categoria_n like 'EL VOLUNTARIO NO SE COMUNICA' or categoria_n like 'INCUMPLIMIENTO DEL VOLUNTARIO'
)

-- VOLUNTARIO
select distinct categoria_n
from dataset_covid dc 
where categoria_n like '%VOLUNTARIO%' and categoria_n not like 'PROBLEMA%'

update dataset_covid 
set categoria_n = 'VOLUNTARIO'
where categoria_n in (select distinct categoria_n
from dataset_covid dc 
where categoria_n like '%VOLUNTARIO%' and categoria_n not like 'PROBLEMA%') -- habia 143990 registros asi.

select categoria_n, count(*)
from dataset_covid dc 
group by categoria_n
order by categoria_n asc

select distinct categoria_n
from dataset_covid dc 

-- Como seguimos con una cantidad muy grande de categorias que no hacen prudente el analisis decidimos llevarnos la consulta de las categorias_n y normalizarlas fuera del postgres. 
-- Exportamos la consulta:
select distinct categoria_n 
from dataset_covid dc2 

-- Traemos la nueva base de categorias normalizadas en la que tambien agregamos una nueva clasificacion mucho mas generica.
select * 
from categorias_normalizadas_csv

select distinct general 
from categorias_normalizadas_csv 
-- En esta vemos que los temas de las llamadas se segmentan en vacunas, informacion, incumplimiento, sintomas y otros.

-- Agregamos las categorias normalizadas al dataset:
update dataset_covid 
set categoria_n = replace(dataset_covid.categoria_n, dataset_covid.categoria_n ,c.categoria_n1) 
from categorias_normalizadas_csv c
where dataset_covid.categoria_n = c.categoria_n

-- Asi, pasamos de tener 137 categorias distintas a solo 39!
select count(distinct categoria) as cantidad_categorias, count(distinct categoria_n) as cantidad_categorias_normalizadas
from dataset_covid dc

-- Creamos la nueva variable de categorias genericas:
alter table dataset_covid 
add column categoria_general varchar(1000)

-- Cargamos la nueva columna:
update dataset_covid 
set categoria_general = c."general"
from categorias_normalizadas_csv c
where dataset_covid.categoria_n = c.categoria_n1 

-- Las categorias generales que quedaron nulas las agruparemos en la categoria 'OTRO'
update dataset_covid 
set categoria_general = 'OTRO'
from categorias_normalizadas_csv c
where dataset_covid.categoria_n is null

select distinct categoria_general from dataset_covid dc 

----------------------------------------------------------------------------------------------------------------------------------------------------
select MIN(fecha_ingreso_n)
from dataset_covid
-- 2020-03-16

select MAX(fecha_ingreso_n)
from dataset_covid
-- 2021-11-05

select distinct *
from dataset_covid_147

------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analisis con casos por dia.
select *
from casos_por_dia_csv 

-- Cambiamos el tipo de dato de la fecha a date.
select to_date(fecha, 'YYYY-MM-DD')
from casos_por_dia_csv cpdc -- funciona

alter table casos_por_dia_csv 
add column fecha_n date

update casos_por_dia_csv 
set fecha_n = to_date(fecha, 'YYYY-MM-DD')

-- Consulta para ver por fecha la cantidad de casos y llamadas.
select c.fecha, c.casos, count(contacto) as llamadas
from casos_por_dia_csv c
join dataset_covid dc on c.fecha_n = date(dc.fecha_ingreso_n) 
group by c.fecha, c.casos

-- Consulta para ver cantidad de casos por barrio
select barrio_n , count(*) as Cantidad
from dataset_covid dc 
group by provincia

-- Consulta para ver cantidad de casos por provincia
select provincia, count(*) as Cantidad
from dataset_covid dc 
group by provincia

-- Consulta para ver cantidad de casos por categoria:
select categoria_n, count(*) as Cantidad
from dataset_covid dc 
group by categoria_n 

-- Consulta para ver cantidad de casos por categoria general:
select categoria_general, count(*) as Cantidad
from dataset_covid dc 
group by categoria_general 

-- Consulta de frecuencia de llamados
select round(avg(segundos),2) as promedio_segundos
from (select extract(hour from AGE(fecha_ingreso_n,LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n))) * 3600 + extract(minute from AGE(fecha_ingreso_n,LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n))) * 60 + extract(second from AGE(fecha_ingreso_n,LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n))) as segundos, fecha_ingreso_n
from dataset_covid dc ) diferencia_segundos(segundos) -- 11.38 segundos entre llamada y llamada.

-- Consulta duracion de consulta promedio:
select round(avg(minutos),2) as promedio_minutos
from (select extract(hour from fecha_cierre_contacto_n - fecha_ingreso_n )*60 + extract(minute from fecha_cierre_contacto_n - fecha_ingreso_n ) + extract(second from fecha_cierre_contacto_n - fecha_ingreso_n ) / 60 as minutos
from dataset_normalizado_csv dc  where extract(hour from fecha_cierre_contacto_n - fecha_ingreso_n) <= 2 and extract(days from fecha_cierre_contacto_n - fecha_ingreso_n ) < 1
) diferencia_minutos(minutos) -- 2 minutos de duracion promedio de la consulta

-- Consulta comparacion categoria de llamados en Primer Ola (Antes Abril 2021) y Segunda Ola (Despues Abril 2021)
-- Primera Ola: 
select categoria_n, count(*) as Cantidad
from dataset_covid dc 
where fecha_ingreso_n < '01/04/2021'
group by categoria_n 
order by Cantidad desc
limit 10
-- Segunda Ola:
select categoria_n, count(*) as Cantidad
from dataset_covid dc 
where fecha_ingreso_n >= '01/04/2021'
group by categoria_n 
order by Cantidad desc
limit 10

-- Llamadas totales por vacunas:
select categoria_n, count(*)
from dataset_covid dc 
where categoria_general = 'VACUNAS'
group by categoria_n 

-- Cantidad de llamadas del exterior:
select count(*)
from dataset_covid dc 
where provincia = 'EXTERIOR' -- 24300

-- Cantidad de llamadas de incumplimiento:
select count(*)
from dataset_covid dc 
where categoria_general = 'INCUMPLIMIENTO' -- 66826

select count(*) from dataset_covid dc 


select barrio_n, count(*)
from dataset_covid dc 
where comuna_n != 'Sin identificar'
group by barrio_n

select contacto, periodo, categoria, fecha_ingreso_n, fecha_cierre_contacto_n, extract(hour from fecha_cierre_contacto_n - fecha_ingreso_n) as dif_horas, extract(day from fecha_cierre_contacto_n - fecha_ingreso_n) as dif_days, categoria_general, extract(hour from fecha_cierre_contacto_n - fecha_ingreso_n)*60 + extract(minute from fecha_cierre_contacto_n - fecha_ingreso_n ) + extract(second from fecha_cierre_contacto_n - fecha_ingreso_n ) / 60 as minutos
from dataset_covid dc


select count(*)
from dataset_covid 

-- Consulta de frecuencia de llamados 
select round(avg(segundos),2) as promedio_minutos
from (select extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) /60
from dataset_covid dc ) diferencia_minutos(segundos) -- 0.2 minutos entre llamadas totales

select fecha_ingreso_n, LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)
from dataset_covid dc 

-- Consulta de frecuencia de llamados TOTAL
select contacto, periodo, fecha_ingreso_n, categoria, categoria_n, categoria_general, extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Total_Min
from dataset_covid dc


-- Consulta de frecuencia de llamados INCUMPLIMIENTO
select contacto, periodo, fecha_ingreso_n, categoria, categoria_n, categoria_general, extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Incumplimieto
from (select * from dataset_covid dc where categoria_general = 'INCUMPLIMIENTO') as df

select avg(df.Frecuencia_Incumplimiento)
from (select extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Incumplimieto
from (select * from dataset_covid dc where categoria_general = 'INCUMPLIMIENTO') as df) as df(Frecuencia_Incumplimiento)


-- Consulta de frecuencia de llamados OTRO
select contacto, periodo, fecha_ingreso_n, categoria, categoria_n, categoria_general, extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Incumplimieto
from (select * from dataset_covid dc where categoria_general = 'OTRO') as df

select avg(df.Frecuencia_Incumplimiento)
from (select extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Incumplimieto
from (select * from dataset_covid dc where categoria_general = 'OTRO') as df) as df(Frecuencia_Incumplimiento)

-- Consulta de frecuencia de llamados INFORMACION
select contacto, periodo, fecha_ingreso_n, categoria, categoria_n, categoria_general, extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Incumplimieto
from (select * from dataset_covid dc where categoria_general = 'INFORMACION') as df

select avg(df.Frecuencia_Incumplimiento)
from (select extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Incumplimieto
from (select * from dataset_covid dc where categoria_general = 'INFORMACION') as df) as df(Frecuencia_Incumplimiento)

-- Consulta de frecuencia de llamados VACUNAS
select contacto, periodo, fecha_ingreso_n, categoria, categoria_n, categoria_general, extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Incumplimieto
from (select * from dataset_covid dc where categoria_general = 'VACUNAS') as df

select avg(df.Frecuencia_Incumplimiento)
from (select extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Incumplimieto
from (select * from dataset_covid dc where categoria_general = 'VACUNAS') as df) as df(Frecuencia_Incumplimiento)

-- Consulta de frecuencia de llamados SINTOMAS
select contacto, periodo, fecha_ingreso_n, categoria, categoria_n, categoria_general, extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Incumplimieto
from (select * from dataset_covid dc where categoria_general = 'SINTOMAS') as df

select avg(df.Frecuencia_Incumplimiento)
from (select extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Incumplimieto
from (select * from dataset_covid dc where categoria_general = 'SINTOMAS') as df) as df(Frecuencia_Incumplimiento)

select distinct categoria_general from dataset_covid dc 

-- UNION
select contacto, periodo, fecha_ingreso_n, categoria, categoria_n, categoria_general, extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Total
from (select * from dataset_covid dc where categoria_general = 'INCUMPLIMIENTO') as df
union 
select contacto, periodo, fecha_ingreso_n, categoria, categoria_n, categoria_general, extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Total
from (select * from dataset_covid dc where categoria_general = 'OTRO') as df
union 
select contacto, periodo, fecha_ingreso_n, categoria, categoria_n, categoria_general, extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Total
from (select * from dataset_covid dc where categoria_general = 'INFORMACION') as df
union 
select contacto, periodo, fecha_ingreso_n, categoria, categoria_n, categoria_general, extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Total
from (select * from dataset_covid dc where categoria_general = 'VACUNAS') as df
union 
select contacto, periodo, fecha_ingreso_n, categoria, categoria_n, categoria_general, extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Total
from (select * from dataset_covid dc where categoria_general = 'SINTOMAS') as df


select categoria_general, avg(frecuencia_total)
from (select contacto, periodo, fecha_ingreso_n, categoria, categoria_n, categoria_general, extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Total
from (select * from dataset_covid dc where categoria_general = 'INCUMPLIMIENTO') as df
union 
select contacto, periodo, fecha_ingreso_n, categoria, categoria_n, categoria_general, extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Total
from (select * from dataset_covid dc where categoria_general = 'OTRO') as df
union 
select contacto, periodo, fecha_ingreso_n, categoria, categoria_n, categoria_general, extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Total
from (select * from dataset_covid dc where categoria_general = 'INFORMACION') as df
union 
select contacto, periodo, fecha_ingreso_n, categoria, categoria_n, categoria_general, extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Total
from (select * from dataset_covid dc where categoria_general = 'VACUNAS') as df
union 
select contacto, periodo, fecha_ingreso_n, categoria, categoria_n, categoria_general, extract(hour from  fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) * 60 + extract(minute from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) + extract(second from fecha_ingreso_n - LAG(fecha_ingreso_n, 1, fecha_ingreso_n) OVER (ORDER BY fecha_ingreso_n)) / 60 as Frecuencia_Total
from (select * from dataset_covid dc where categoria_general = 'SINTOMAS') as df) as df
group by categoria_general


select *
from public.dataset_normalizado_csv
where barrio_n = 'PATERNAL'

select distinct categoria_n
from dataset_covid dc 
where categoria_general = 'INFORMACION'

select distinct provincia
from dataset_normalizado_csv dnc 
order by provincia

update dataset_normalizado_csv 
set comuna_n = 'COMUNA 15'
where barrio_n = 'PATERNAL'

update dataset_normalizado_csv 
set provincia = 'TIERRA DEL FUEGO'
where provincia = 'USHUAIA'


select barrio_n, count(*) as cantidad
from dataset_normalizado_csv dnc 
group by barrio_n 
order by cantidad desc
limit 4

select contacto, fecha_ingreso, periodo, categoria, barrio, barrio_n,comuna, comuna_n, domicilio_calle, domicilio_altura
from dataset_normalizado_csv dnc 
where barrio_n = 'CABA'


select distinct barrio_n, comuna_n
from dataset_normalizado_csv dnc 
where comuna_n != 'Sin identificar'

update dataset_normalizado_csv 
set barrio_n = 'SAAVEDRA'
where barrio_n = 'SAVEDRA'

select * 
from dataset_normalizado_csv dnc 
where barrio_n = 'SAVEDRA'


select d.barrio_n, d.domicilio_calle, domicilio_altura


update dataset_normalizado_csv
set barrio_n = replace(dataset_normalizado_csv.barrio_n, dataset_normalizado_csv.barrio_n,c.barrio_nuevo) 
from barrios_caba_normalizados_csv c
where dataset_normalizado_csv.barrio_n = c.barrio_n and dataset_normalizado_csv.domicilio_calle = c.domicilio_calle  
and dataset_normalizado_csv.domicilio_altura = c.domicilio_altura and c.barrio_nuevo is not null


update dataset_normalizado_csv
set comuna_n = replace(comuna_n, comuna_n,c.comuna) 
from comunas_y_barrios_csv c
where barrio_n = c.barrio and barrio_n != '' and barrio_n is not null 

update dataset_normalizado_csv 
set barrio_n = 'SAAVEDRA'
where barrio_n = 'SAVEDRA'

update dataset_normalizado_csv 
set barrio_n = 'VILLA GRAL. MITRE'
where barrio_n = 'VILLA GENERAL MITRE'

update dataset_normalizado_csv 
set barrio_n = 'BOCA'
where barrio_n = 'LA BOCA'

select *
from dataset_normalizado_csv dnc 

select count(*)
from dataset_normalizado_csv dnc 
where provincia = 'EXTERIOR'

select count(*)
from dataset_normalizado_csv dnc 
where provincia != 'EXTERIOR'


select distinct detalle_reclamo
from dataset_normalizado_csv dnc 

select provincia, count(*)
from dataset_normalizado_csv dnc 
group by provincia

select date(fecha_ingreso_n) as fecha, count(*)
from dataset_normalizado_csv dnc 
where categoria_general = 'VACUNAS'
group by date(fecha_ingreso_n) 
order by date(fecha_ingreso_n) 

select categoria_general, count(*)
from dataset_normalizado_csv dnc 
group by categoria_general 


select contacto, categoria, categoria_n, fecha_ingreso_n, fecha_cierre_contacto_n, categoria_general, trunc(extract(hour from fecha_cierre_contacto_n - fecha_ingreso_n )*60 + extract(minute from fecha_cierre_contacto_n - fecha_ingreso_n ) + extract(second from fecha_cierre_contacto_n - fecha_ingreso_n ) / 60 ,0) as minutos, ((extract(hour from fecha_cierre_contacto_n - fecha_ingreso_n )*60 + extract(minute from fecha_cierre_contacto_n - fecha_ingreso_n ) + extract(second from fecha_cierre_contacto_n - fecha_ingreso_n ) / 60)-trunc(extract(hour from fecha_cierre_contacto_n - fecha_ingreso_n)*60 + extract(minute from fecha_cierre_contacto_n - fecha_ingreso_n ) + extract(second from fecha_cierre_contacto_n - fecha_ingreso_n ) / 60,0)) * 60 as segundos
from dataset_normalizado_csv dnc dc

select count(*)
from dataset_normalizado_csv dnc
where provincia != 'EXTERIOR' and provincia != 'NO IDENTIFICADO'

select distinct provincia
from dataset_normalizado_csv dnc 



select count(*)
from dataset_normalizado_csv dnc 
where comuna_n != 'Sin identificar'

select distinct comuna_n
from dataset_normalizado_csv dnc 

select distinct categoria
from dataset_normalizado_csv dnc

select date(fecha_ingreso_n), provincia, count(*)
from dataset_normalizado_csv dnc 
where provincia != 'NO IDENTIFICADO'
group by date(fecha_ingreso_n), provincia
order by date(fecha_ingreso_n) 



-- Descargo solo los datos que no tienen provincia ("NO IDENTIFICADO").
-- Los proceso
-- Actualizo los datos que no tengan pronvincia
select barrio_n, comuna_n, lat, long, count(*)
from dataset_normalizado_csv dnc 
where provincia = 'NO IDENTIFICADO' or lat !=  null or long != null
group by barrio_n, comuna_n, lat, long
order by count(*) desc

select count(*)
from dataset_normalizado_csv dnc 
where provincia = 'NO IDENTIFICADO' or lat !=  null or long != null -- antes: 1868393 43% -- ahora: 1287002 29,88% -- ahora2 = 833.286 -- 473003

select count(*)
from dataset_normalizado_csv dnc 


select lat, long, count(*)
from dataset_normalizado_csv dnc 
group by lat, long 
order by count(*) desc


select lat, long from dataset_normalizado_csv dnc 

alter table direcciones1_csv 
add column latitud_n float8

alter table direcciones1_csv 
add column longitud_n float8


select count(*) from direcciones1_csv dc -- 10000 --110285

select * from direcciones1_csv dc 

update public.direcciones1_csv
set latitud_n = cast(cast(lat as float8)/(power(10,length(lat)-3)) as float8)


update direcciones1_csv 
set longitud_n = cast(cast(long as float8)/(power(10,length(long)-3)) as float8)

select * from direcciones1_csv dc 

select lat, latitud, cast(cast(lat as float8)/(power(10,length(lat)-3)) as float8) as latitud_n, cast(cast(lat as float8)/(power(10,length(lat)-3)) as float8) as longitud_n, provincia
from direcciones1_csv dc 


select d.lat, d.long, dc.latitud_n, dc.longitud_n, dc.provincia, d.provincia
from dataset_normalizado_csv d
inner join direcciones1_csv dc on d.lat = dc.latitud_n and d.long = dc.longitud_n


update dataset_normalizado_csv 
set provincia = replace(dataset_normalizado_csv.provincia, dataset_normalizado_csv.provincia, d.provincia)
from direcciones1_csv d
where dataset_normalizado_csv.lat = d.latitud_n and dataset_normalizado_csv.long = d.longitud_n

select *
from direcciones1_csv dc 
where lat like '-3460368%'


select contacto, periodo, lat, long, provincia
from dataset_normalizado_csv dnc 



select d.barrio_n, d.comuna_n, d.lat, d.long, dc.latitud_n, dc.longitud_n, count(*)
from dataset_normalizado_csv d 
join direcciones1_csv dc  on dc.latitud_n = d.lat and dc.longitud_n = d.long
where d.provincia = 'NO IDENTIFICADO' or d.lat !=  null or d.long != null
group by d.barrio_n, d.comuna_n, d.lat, d.long, dc.latitud_n, dc.longitud_n
order by count(*) desc

update dataset_normalizado_csv 
set provincia = 'NO IDENTIFICADO'
where provincia = null

select contacto, periodo, lat, long, provincia from dataset_normalizado_csv dnc 

select count(*)
from dataset_normalizado_csv dnc 
where provincia = 'CABA'


select barrio_n, count(*)
from dataset_normalizado_csv dnc 
where provincia = 'CABA' and barrio_n != ''
group by barrio_n





select cast(fecha_aplicacion as date), count(*)
from datos_nomivac_covid19 dnc 
where fecha_aplicacion != 'S.I.'
group by cast(fecha_aplicacion as date) 



select cast(fecha_aplicacion as date)
from datos_nomivac_covid19 dnc 


select distinct periodo
from dataset_normalizado_csv dnc 



