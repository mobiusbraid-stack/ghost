// cydonia-sinter-mesh/src/backpressure_router.rs
// BSL 1.1 License - Cydonia Foundry

use std::cmp::min;

const BASE_DELAY_MS: u64 = 10;
const MAX_DELAY_MS: u64 = 2500;

#[derive(Debug, Clone, Copy)]
pub struct ClusterNodeState {
    pub active_nodes: u32,
    pub dropped_packets: u32,
    pub collision_count: u32,
}

impl ClusterNodeState {
    /// Computes dynamic transmission backoff delay in milliseconds
    pub fn compute_backpressure_delay(&self) -> u64 {
        if self.active_nodes == 0 {
            return BASE_DELAY_MS;
        }

        let total_stress = (self.dropped_packets as u64) + (self.collision_count as u64);
        let congestion_level = (total_stress * 100) / (self.active_nodes as u64);

        if congestion_level < 10 {
            return BASE_DELAY_MS;
        }

        let shift = min(congestion_level / 20, 8);
        let calculated_delay = BASE_DELAY_MS * (1 << shift);

        min(calculated_delay, MAX_DELAY_MS)
    }
}
