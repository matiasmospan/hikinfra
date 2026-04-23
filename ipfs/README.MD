# 🛡️ HIK IPFS Cluster v2.0
## Persistence Layer: High Availability & Auto-Replication

Este componente gestiona el almacenamiento distribuido de las evidencias de **Human Is Kind**. Asegura que el "Human Source" y los JSON de auditoría sean resilientes a fallos de infraestructura.

### 1. Resumen de Funcionalidades
- **Replicación Automática:** Cada archivo subido se replica en N nodos del clúster automáticamente.
- **HA nativa:** Uso de StatefulSets con anti-afinidad para dispersión geográfica de la evidencia.
- **Performance I/O:** Optimizado para discos SSD para reducir latencia en el anclaje de CIDs.

### 2. Arquitectura de Componentes
- **Kubo (IPFS):** El daemon que gestiona el almacenamiento de bloques.
- **Cluster Peer:** Sidecar que coordina los "pins" globales y mantiene el estado compartido (CRDT).
- **Service Headless:** Facilita el descubrimiento P2P interno.

### 🚀 Despliegue Zero-Ops
A diferencia de otras implementaciones, este Chart autogestiona su seguridad:
1.  **Generación de Secretos:** El `cluster-secret` se genera aleatoriamente en la primera instalación.
2.  **Persistencia de Identidad:** Durante un `helm upgrade`, el secreto se mantiene intacto gracias a la función `lookup`, evitando que los nodos pierdan conectividad entre sí.
3.  **Self-Healing:** Los nodos secundarios reintentan la conexión al bootstrap automáticamente si el nodo principal está reiniciando.

**Comando Único:**
```bash
helm install hik-ipfs ./hik-ipfs-chart`
```

### 4. Parámetros de Disponibilidad
- **SLA Estimado:** 99.99% para acceso a datos.
- **Resiliencia:** Tolera la pérdida de (N-1) nodos sin pérdida de integridad de la evidencia.

### 🔗 Conectividad y Discovery
- **Discovery Interno:** Se utiliza un Headless Service para que los nodos resuelvan sus IPs mediante DNS de Kubernetes (`$(POD_NAME).$(SERVICE_NAME)`).
- **Bootstrap:** El nodo `hik-ipfs-0` actúa como punto de encuentro inicial. Los nodos subsiguientes se auto-configuran al inicio mediante el `entrypoint.sh`.

### 🛠️ Puertos Clave para HIK Governance
| Puerto | Servicio | Uso |
| :--- | :--- | :--- |
| **5001** | IPFS Kubo API | Subida directa de archivos (Legacy/Debug) |
| **9094** | Cluster API | **Recomendado:** Subida con replicación inmediata |
| **4001** | IPFS P2P | Comunicación entre nodos de la red global |
| **9096** | Cluster Swarm | Comunicación interna del clúster de replicación |

### 🛡️ Diseño de Red y Seguridad (Zero-Trust)
El despliegue utiliza una arquitectura de doble servicio para facilitar la segmentación mediante **NetworkPolicies**:
- **Tráfico de Aplicación:** Se canaliza vía `hik-ipfs-api`, permitiendo el balanceo de carga y la abstracción del número de réplicas.
- **Tráfico de Infraestructura:** El servicio `headless` queda reservado para la comunicación interna del protocolo IPFS Cluster, minimizando la superficie de exposición del swarm.

---