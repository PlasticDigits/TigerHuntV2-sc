// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {TigerHuntAccessManager} from "../src/access/TigerHuntAccessManager.sol";
import {WorldRegistry} from "../src/registries/WorldRegistry.sol";
import {SpawnRegistry} from "../src/registries/SpawnRegistry.sol";
import {CommandRegistry} from "../src/registries/CommandRegistry.sol";
import {GameWorldSquare} from "../src/contracts/GameWorldSquare.sol";
import {SetRegistryWrapper} from "../src/registries/SetRegistryWrapper.sol";
import {IWorldRegistry} from "../src/interfaces/IWorldRegistry.sol";

/**
 * @title SetupAccessManager1
 * @dev Script to setup the AccessManager
 */
contract SetupAccessManager1 is Script {
    // Current contracts
    WorldRegistry public oldWorldRegistry;
    SpawnRegistry public oldSpawnRegistry;
    CommandRegistry public oldCommandRegistry;

    // New contracts with AccessManager
    TigerHuntAccessManager public accessManager;
    WorldRegistry public newWorldRegistry;
    SpawnRegistry public newSpawnRegistry;
    CommandRegistry public newCommandRegistry;

    function run() public {
        // Get the deployer address
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        vm.startBroadcast(deployer);

        // Load existing contracts
        oldWorldRegistry = WorldRegistry(
            vm.envAddress("WORLD_REGISTRY_ADDRESS")
        );
        oldSpawnRegistry = SpawnRegistry(
            vm.envAddress("SPAWN_REGISTRY_ADDRESS")
        );
        oldCommandRegistry = CommandRegistry(
            vm.envAddress("COMMAND_REGISTRY_ADDRESS")
        );
        SetRegistryWrapper setRegistry = SetRegistryWrapper(
            vm.envAddress("SET_REGISTRY_ADDRESS")
        );

        // Deploy AccessManager
        accessManager = new TigerHuntAccessManager(deployer);

        // Deploy new contracts
        newWorldRegistry = new WorldRegistry(address(accessManager));
        newSpawnRegistry = new SpawnRegistry(address(accessManager));
        newCommandRegistry = new CommandRegistry(
            setRegistry,
            address(accessManager)
        );

        // Configure AccessManager permissions

        // 1. World Registry permissions
        // Allow WORLD_MANAGER_ROLE to call registerWorld and unregisterWorld
        bytes4[] memory s1 = new bytes4[](1);
        bytes4[] memory s2 = new bytes4[](2);
        bytes4[] memory s3 = new bytes4[](3);
        s2[0] = WorldRegistry.registerWorld.selector;
        s2[1] = WorldRegistry.unregisterWorld.selector;
        accessManager.setTargetFunctionRole(
            address(newWorldRegistry),
            s2,
            accessManager.WORLD_MANAGER_ROLE()
        );

        // Allow SPAWNER_ROLE to call spawnEntity
        s1[0] = WorldRegistry.spawnEntity.selector;
        accessManager.setTargetFunctionRole(
            address(newWorldRegistry),
            s1,
            accessManager.SPAWNER_ROLE()
        );

        // Allow ADMIN_ROLE to configure dependencies
        s1[0] = WorldRegistry.setDependencies.selector;
        accessManager.setTargetFunctionRole(
            address(newWorldRegistry),
            s1,
            accessManager.ADMIN_ROLE()
        );

        // 2. Spawn Registry permissions
        // Allow SPAWN_MANAGER_ROLE to manage spawn worlds
        s1[0] = SpawnRegistry.addValidSpawnWorld.selector;
        s1[1] = SpawnRegistry.removeValidSpawnWorld.selector;
        accessManager.setTargetFunctionRole(
            address(newSpawnRegistry),
            s1,
            accessManager.SPAWN_MANAGER_ROLE()
        );

        // Allow ADMIN_ROLE to configure dependencies
        s1[0] = SpawnRegistry.setDependencies.selector;
        accessManager.setTargetFunctionRole(
            address(newSpawnRegistry),
            s1,
            accessManager.ADMIN_ROLE()
        );

        // 3. Command Registry permissions
        // Allow COMMAND_MANAGER_ROLE to manage commands
        s3[0] = CommandRegistry.registerCommand.selector;
        s3[1] = CommandRegistry.allowCommand.selector;
        s3[2] = CommandRegistry.disableCommand.selector;
        accessManager.setTargetFunctionRole(
            address(newCommandRegistry),
            s3,
            accessManager.COMMAND_MANAGER_ROLE()
        );

        vm.stopBroadcast();
    }
}
