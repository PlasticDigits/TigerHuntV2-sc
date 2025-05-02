// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity 0.8.29;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";

/**
 * @title TigerHuntAccessManager
 * @dev Centralized access control for TigerHunt contracts
 */
contract TigerHuntAccessManager is AccessManager {
    // Define role IDs (moving from bytes32 to uint64)
    uint64 public constant WORLD_MANAGER_ROLE = 1;
    uint64 public constant SPAWN_MANAGER_ROLE = 2;
    uint64 public constant COMMAND_MANAGER_ROLE = 3;
    uint64 public constant PORTAL_MANAGER_ROLE = 4;
    uint64 public constant ROUTER_ROLE = 5;
    uint64 public constant SPAWNER_ROLE = 6;

    constructor(address initialAdmin) AccessManager(initialAdmin) {}
}
