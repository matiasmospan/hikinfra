# HIK Infrastructure 2.0: Hyperledger Besu Layer

Este componente representa la columna vertebral de integridad de **Human Is Kind (HIK)**. Es un clúster de Hyperledger Besu optimizado para **Performance Extrema** y **Alta Disponibilidad (HA)**, diseñado para correr en entornos Cloud-Native (Kubernetes).## 🚀 Características de la Solución- **Consenso QBFT:** Tolerancia a fallos bizantinos con finalidad inmediata (1-2s).- **Redundancia Multi-Zona:** Despliegue distribuido para evitar caídas por fallas de Datacenter.- **Auto-Deployment:** Job integrado para el despliegue automático del contrato `HIKRegistry`.- **Seguridad "Zero-Exposure":** Gestión de llaves privadas mediante Secrets de Kubernetes.

## Requisitos Previos
1.  **Cluster de Kubernetes** (GKE recomendado para aprovechar discos SSD Premium).
2.  **Helm 3.x** instalado.
3.  **kubectl** configurado.
4.  **Dirección y Clave Privada de Administrador:** Generada previamente para fondear el `genesis.json`.

## Procedimiento de Despliegue
### Paso 1: Preparación de Secretos

Para evitar el "loop" de configuración, creamos el secreto con la clave privada que tendrá los fondos iniciales definidos en el bloque génesis.```bash
kubectl create secret generic besu-deployer-key --from-literal=key=0xTU_PRIVATE_KEY_AQUI

### Paso 2: Configuración del values.yaml

Asegúrate de que los nodeSelectors coincidan con tus nodos dedicados a Blockchain para evitar ruidos de performance con otros componentes (vLLM, etc).

```YAML
nodes:
  replicaCount: 3
  storage:
    class: premium-rwo # SSD
  nodeSelector:
    dedicated: blockchain

contract:
  deploy: true
  deployerAddress: "0xTU_DIRECCION_PUBLICA" # Debe coincidir con el Secret anterior
```

### Paso 3: Instalación del Chart

```bash

helm install hik-besu ./hik-besu-chart
```

## Variables de Entorno (HIK Engine Integration)2
Una vez desplegado el clúster, el componente hik-core (Go) debe configurarse con las siguientes variables para conectar con esta capa:

| Variable            | Descripción                       | Valor Sugerido             |
|---------------------|-----------------------------------|----------------------------|
|HIK_RPC_URL          | Endpoint interno del clúster Besu | http://besu-internal:8545  |
|HIK_CONTRACT_ADDRESS | Dirección del contrato desplegado | (Obtenida del logs del Job)|
|HIK_CHAIN_ID         | ID  de red privada HIK            | 1337                       |
|HIK_BATCH_SIZE       | Cantidad de evidencias por TX     | 10 (Performance Extrema)   |
|HIK_GAS_LIMIT        | Límite de gas por anclaje         | 500000                     | 

## Puntos Extras (Resiliencia Avanzada)

### Liveness & Readiness Probes
El chart incluye chequeos que no solo miran si el proceso corre, sino si el nodo está sincronizado:
**Readiness:** El nodo solo recibe tráfico del Explorer si eth_syncing es false.
**Liveness:** Si el nodo no ha reportado un nuevo bloque en 60 segundos, Kubernetes lo reinicia automáticamente.

### Monitoreo con Prometheus
Besu expone métricas en el puerto 9545. Se recomienda activar el PodMonitor para trackear:
**TPS (Transactions Per Second)**: Monitorear picos de anclaje de HIK.
**Peer Count**: Asegurar que los 3 nodos validadores se vean entre sí constantemente.

### Backup de Estado
Aunque el StatefulSet mantiene los discos, se recomienda configurar un VolumeSnapshot diario para los discos SSD de los validadores para recuperarse ante corrupciones lógicas de la DB de Besu.

## Verificación del Despliegue
Para confirmar que el contrato se desplegó correctamente y la red está activa:

```Bash
# Ver logs del deployer
kubectl logs -l job-name=hik-besu-contract-deployer# Ver estado del clúster
kubectl get statefulset hik-besu-validator
```