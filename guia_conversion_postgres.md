# Guía de Conversión: PostgreSQL 16 → PostgreSQL 12

## ⚠️ Advertencias Importantes

**Esta es una operación de DOWNGRADE** que puede resultar en pérdida de funcionalidad. PostgreSQL 16 tiene características que NO existen en PostgreSQL 12.

### Características de PG16 que NO funcionarán en PG12:

1. **MERGE statements** - No soportado en PG12
2. **Mejoras en JSON/JSONB** - Algunas funciones no están disponibles
3. **ICU locale provider mejorado** - Diferencias en collations
4. **Logical replication mejorada** - Características limitadas
5. **Mejoras en particionado** - Algunas opciones no disponibles
6. **Nuevas funciones de SQL** - Múltiples funciones agregadas en versiones posteriores

---

## Método 1: Conversión con pg_dump (RECOMENDADO)

Si aún tienes acceso al servidor PostgreSQL 16, este es el método más seguro:

### Paso 1: Exportar en formato compatible
```bash
# En el servidor con PostgreSQL 16
pg_dump -U postgres \
    --format=plain \
    --no-owner \
    --no-privileges \
    --no-tablespaces \
    nombre_base_datos > backup_compatible.sql
```

### Paso 2: Limpiar el archivo SQL
```bash
# Usar el script de conversión
./convert_pg16_to_pg12.sh backup_compatible.sql backup_pg12.sql
```

### Paso 3: Restaurar en PostgreSQL 12
```bash
# Crear base de datos en PG12
createdb -U postgres nombre_base_datos

# Restaurar
psql -U postgres -d nombre_base_datos -f backup_pg12.sql 2>&1 | tee restore.log
```

---

## Método 2: Si solo tienes el archivo de backup

### Opción A: Backup en formato custom (.dump)
```bash
# Ver contenido del backup
pg_restore -l backup.dump > backup_list.txt

# Restaurar selectivamente (omitiendo elementos problemáticos)
pg_restore -U postgres \
    --format=custom \
    --no-owner \
    --no-privileges \
    -d nombre_base_datos \
    backup.dump 2>&1 | tee restore.log
```

### Opción B: Backup en formato SQL plano
```bash
# Usar el script de conversión
./convert_pg16_to_pg12.sh backup_pg16.sql backup_pg12.sql

# Revisar y editar manualmente el archivo
nano backup_pg12.sql

# Restaurar
psql -U postgres -d nombre_base_datos -f backup_pg12.sql
```

---

## Ajustes Manuales Comunes

### 1. Eliminar MERGE statements
```sql
-- PostgreSQL 16 (NO funciona en PG12)
MERGE INTO tabla_destino AS t
USING tabla_origen AS s
ON t.id = s.id
WHEN MATCHED THEN UPDATE SET ...
WHEN NOT MATCHED THEN INSERT ...;

-- Alternativa para PostgreSQL 12 (usar INSERT ... ON CONFLICT)
INSERT INTO tabla_destino (id, campo1, campo2)
SELECT id, campo1, campo2 FROM tabla_origen
ON CONFLICT (id) DO UPDATE SET
    campo1 = EXCLUDED.campo1,
    campo2 = EXCLUDED.campo2;
```

### 2. Ajustar funciones JSON
```sql
-- Algunas funciones nuevas pueden necesitar alternativas
-- Revisar la documentación de PG12 para funciones JSON disponibles
```

### 3. Problemas con Collations/Locales
```sql
-- Si hay errores de collation, puedes necesitar:
-- 1. Cambiar a collation disponible en PG12
ALTER TABLE mi_tabla ALTER COLUMN mi_columna TYPE text COLLATE "es_ES.utf8";

-- 2. O eliminar la collation específica
ALTER TABLE mi_tabla ALTER COLUMN mi_columna TYPE text COLLATE "default";
```

### 4. GENERATED ALWAYS AS IDENTITY
```sql
-- PG16 puede tener sintaxis extendida
-- Simplificar a:
CREATE TABLE ejemplo (
    id SERIAL PRIMARY KEY,
    nombre TEXT
);
```

---

## Proceso Paso a Paso Recomendado

### 1. Preparación
```bash
# Instalar PostgreSQL 12 en un servidor de pruebas
sudo apt update
sudo apt install postgresql-12

# Verificar versión
psql --version
```

### 2. Conversión del Backup
```bash
# Copiar el archivo de backup
cp /ruta/al/backup_pg16.sql /tmp/

# Ejecutar conversión
./convert_pg16_to_pg12.sh /tmp/backup_pg16.sql /tmp/backup_pg12.sql
```

### 3. Revisar el Archivo Convertido
```bash
# Buscar posibles problemas
grep -i "merge" backup_pg12.sql
grep -i "generated always" backup_pg12.sql
grep -i "icu_locale" backup_pg12.sql
grep -i "locale_provider" backup_pg12.sql
```

### 4. Restauración de Prueba
```bash
# Crear base de datos de prueba
createdb -U postgres test_agencia

# Restaurar con logging
psql -U postgres -d test_agencia -f backup_pg12.sql 2>&1 | tee restore.log

# Revisar errores
grep -i "error" restore.log
```

### 5. Validación
```sql
-- Conectar a la base de datos
psql -U postgres -d test_agencia

-- Verificar tablas
\dt

-- Verificar datos
SELECT count(*) FROM tabla_principal;

-- Verificar integridad
-- (ejecutar queries específicas de tu aplicación)
```

### 6. Corrección de Errores
Si hay errores en el restore.log:
1. Editar backup_pg12.sql manualmente
2. Buscar la línea problemática
3. Ajustar o comentar según sea necesario
4. Volver a intentar la restauración

---

## Checklist de Validación Post-Restauración

- [ ] Todas las tablas fueron creadas
- [ ] Los datos se importaron correctamente (verificar counts)
- [ ] Las secuencias están en los valores correctos
- [ ] Los índices fueron creados
- [ ] Las foreign keys funcionan
- [ ] Los triggers están activos
- [ ] Las vistas funcionan correctamente
- [ ] Los stored procedures/funciones funcionan
- [ ] Los permisos están configurados (si aplica)
- [ ] La aplicación puede conectarse y funcionar

---

## Comandos Útiles para Diagnóstico

```sql
-- Ver todas las tablas
\dt

-- Ver tamaño de la base de datos
\l+

-- Ver esquema de una tabla
\d+ nombre_tabla

-- Verificar secuencias
SELECT * FROM pg_sequences;

-- Verificar funciones
\df

-- Verificar triggers
SELECT * FROM pg_trigger;

-- Ver índices
\di

-- Estadísticas de la base de datos
SELECT 
    schemaname,
    tablename,
    n_live_tup as row_count
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;
```

---

## Alternativa: Usar Docker para Pruebas

```bash
# Levantar PostgreSQL 12 en Docker
docker run -d \
    --name postgres12-test \
    -e POSTGRES_PASSWORD=mysecretpassword \
    -p 5432:5432 \
    -v /ruta/al/backup:/backup \
    postgres:12

# Conectar
docker exec -it postgres12-test psql -U postgres

# Restaurar dentro del contenedor
docker exec -i postgres12-test psql -U postgres -d postgres < backup_pg12.sql
```

---

## Contacto y Soporte

Si encuentras problemas específicos:
1. Revisa el restore.log para errores específicos
2. Consulta la documentación de PostgreSQL 12: https://www.postgresql.org/docs/12/
3. Compara con la documentación de PostgreSQL 16 para ver qué características nuevas estás usando

**Recuerda: SIEMPRE haz pruebas en un ambiente de desarrollo antes de aplicar en producción.**
