// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

/**
 * @title SinterMeshBackpressure
 * @notice On-chain dynamic backpressure controller for Sinter Lattice clusters.
 */
contract SinterMeshBackpressure {

    uint256 public constant BASE_BACKOFF_MS = 10;
    uint256 public constant MAX_BACKOFF_MS = 2500;

    struct ClusterMetrics {
        uint32 activeNodes;
        uint32 droppedPackets;
        uint32 collisionCount;
        uint256 lastUpdated;
    }

    mapping(uint256 => ClusterMetrics) public clusterData;

    event BackpressureAdjusted(uint256 indexed clusterId, uint256 recommendedDelayMs, uint256 congestionLevel);

    /**
     * @notice Calculates dynamic backoff delay (ms) using exponential backpressure logic.
     */
    function calculateBackpressure(uint256 clusterId) public view returns (uint256 delayMs, uint256 congestionLevel) {
        ClusterMetrics memory metrics = clusterData[clusterId];
        if (metrics.activeNodes == 0) return (BASE_BACKOFF_MS, 0);

        // Congestion ratio = (collisions + drops) * 100 / activeNodes
        congestionLevel = ((uint256(metrics.collisionCount) + uint256(metrics.droppedPackets)) * 100) / uint256(metrics.activeNodes);

        if (congestionLevel < 10) {
            return (BASE_BACKOFF_MS, congestionLevel);
        }

        // Exponential backoff: Base * 2^(congestionRatio / 20)
        uint256 shift = congestionLevel / 20;
        if (shift > 8) shift = 8; // Cap exponential growth
        
        delayMs = BASE_BACKOFF_MS * (1 << shift);
        if (delayMs > MAX_BACKOFF_MS) {
            delayMs = MAX_BACKOFF_MS;
        }

        return (delayMs, congestionLevel);
    }

    /**
     * @notice Updates network metrics for a target cluster slot.
     */
    function reportClusterTelemetry(uint256 clusterId, uint32 nodes, uint32 drops, uint32 collisions) external {
        clusterData[clusterId] = ClusterMetrics({
            activeNodes: nodes,
            droppedPackets: drops,
            collisionCount: collisions,
            lastUpdated: block.timestamp
        });

        (uint256 delay, uint256 congestion) = calculateBackpressure(clusterId);
        emit BackpressureAdjusted(clusterId, delay, congestion);
    }
}
