#!/bin/bash

# Script para convertir backup de PostgreSQL 16 a PostgreSQL 12
# Uso: ./convert_pg16_to_pg12.sh <archivo_backup_pg16> <archivo_salida_pg12>

if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <archivo_backup_pg16> <archivo_salida_pg12>"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"

echo "Convirtiendo backup de PostgreSQL 16 a PostgreSQL 12..."
echo "Archivo de entrada: $INPUT_FILE"
echo "Archivo de salida: $OUTPUT_FILE"

# Verificar que el archivo de entrada existe
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: El archivo $INPUT_FILE no existe"
    exit 1
fi

# Crear archivo temporal
TEMP_FILE="${OUTPUT_FILE}.tmp"

# Procesar el archivo
cat "$INPUT_FILE" | \
    # Eliminar referencias a PostgreSQL 16
    sed 's/PostgreSQL 16/PostgreSQL 12/g' | \
    # Eliminar COLLATION específica de PG16 si existe
    sed 's/COLLATION "icu_/COLLATION "/g' | \
    # Eliminar opciones de ICU que no existen en PG12
    sed '/LOCALE_PROVIDER = icu/d' | \
    sed '/ICU_LOCALE/d' | \
    sed '/BUILTIN = true/d' | \
    # Eliminar procedimientos GENERATED ALWAYS AS IDENTITY mejorados de PG16
    sed 's/GENERATED ALWAYS AS IDENTITY/SERIAL/g' | \
    # Eliminar opciones de merge que no existen en PG12
    sed '/MERGE INTO/d' | \
    # Comentar comandos que puedan no ser compatibles
    sed 's/^\(.*ALTER DATABASE.*SET.*\)/-- \1 -- Verificar compatibilidad/' | \
    # Eliminar funciones JSON mejoradas de PG16
    sed 's/jsonb_path_query_first/jsonb_path_query/g' > "$TEMP_FILE"

# Mover el archivo temporal al archivo de salida
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo ""
echo "Conversión completada!"
echo "Archivo generado: $OUTPUT_FILE"
echo ""
echo "IMPORTANTE - Pasos siguientes:"
echo "1. Revisa manualmente el archivo $OUTPUT_FILE"
echo "2. Busca cualquier referencia a características de PG16"
echo "3. Prueba la restauración en un ambiente de prueba primero"
echo "4. Comandos para restaurar:"
echo ""
echo "   # Crear base de datos en PostgreSQL 12"
echo "   createdb -U postgres nombre_base_datos"
echo ""
echo "   # Restaurar el backup"
echo "   psql -U postgres -d nombre_base_datos -f $OUTPUT_FILE"
echo ""
echo "ADVERTENCIAS:"
echo "- Este script hace conversiones básicas"
echo "- Algunas características avanzadas de PG16 pueden requerir ajustes manuales"
echo "- SIEMPRE prueba en un ambiente de desarrollo primero"
