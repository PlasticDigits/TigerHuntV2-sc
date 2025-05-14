// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {SpawnRegistry} from "../src/registries/SpawnRegistry.sol";
import {WorldRegistry} from "../src/registries/WorldRegistry.sol";
import {IGameWorld} from "../src/interfaces/IGameWorld.sol";
import {MockEntityNFT} from "./mocks/MockEntityNFT.sol";
import {MockGameWorld} from "./mocks/MockGameWorld.sol";
import {TigerHuntAccessManager} from "../src/access/TigerHuntAccessManager.sol";
import {RegistryUtils} from "../src/libraries/RegistryUtils.sol";
import {IEntityNFT} from "../src/interfaces/IEntityNFT.sol";
import {GameEntity} from "../src/structs/GameEntity.sol";
import {EntityWorldDatastore} from "../src/registries/EntityWorldDatastore.sol";
import {EntityWorldReducer} from "../src/registries/EntityWorldReducer.sol";
import {IEntityWorldDatastore} from "../src/interfaces/IEntityWorldDatastore.sol";
import {IEntityWorldReducer} from "../src/interfaces/IEntityWorldReducer.sol";

contract SpawnRegistryTest is Test {
    SpawnRegistry public spawnRegistry;
    WorldRegistry public worldRegistry;
    EntityWorldDatastore public entityWorldDatastore;
    EntityWorldReducer public entityWorldReducer;
    TigerHuntAccessManager public accessManager;
    MockEntityNFT public entityNft1;
    MockEntityNFT public entityNft2;
    address public entityHolder;
    GameEntity public gameEntity1;
    GameEntity public gameEntity2;
    GameEntity public gameEntity3;
    GameEntity public gameEntity4;
    MockGameWorld public world1;
    MockGameWorld public world2;
    address public spawnManager;
    address public nonManager;
    address public admin;

    function setUp() public {
        // Create test addresses
        admin = makeAddr("admin");
        spawnManager = makeAddr("spawnManager");
        nonManager = makeAddr("nonManager");
        entityHolder = makeAddr("entityHolder");

        // Deploy AccessManager and contracts
        accessManager = new TigerHuntAccessManager(admin);
        worldRegistry = new WorldRegistry(address(accessManager));
        spawnRegistry = new SpawnRegistry(address(accessManager));

        // Create entityNFTs and worlds
        entityNft1 = new MockEntityNFT();
        entityNft2 = new MockEntityNFT();
        world1 = new MockGameWorld();
        world2 = new MockGameWorld();

        entityNft1.mint(entityHolder, 1);
        gameEntity1 = GameEntity({entityNFT: entityNft1, entityId: 1});
        entityNft1.mint(entityHolder, 2);
        gameEntity2 = GameEntity({entityNFT: entityNft1, entityId: 2});
        entityNft2.mint(entityHolder, 1);
        gameEntity3 = GameEntity({entityNFT: entityNft2, entityId: 1});
        entityNft2.mint(entityHolder, 2);
        gameEntity4 = GameEntity({entityNFT: entityNft2, entityId: 2});

        // Create and set up EntityWorldDatastore and EntityWorldReducer
        entityWorldDatastore = new EntityWorldDatastore(address(accessManager));
        entityWorldReducer = new EntityWorldReducer(address(accessManager));

        vm.startPrank(admin);
        // Configure permissions for EntityWorldDatastore
        bytes4[] memory datastoreSelectors = new bytes4[](1);
        datastoreSelectors[0] = EntityWorldDatastore.setEntityWorldId.selector;
        accessManager.setTargetFunctionRole(
            address(entityWorldDatastore),
            datastoreSelectors,
            accessManager.ADMIN_ROLE()
        );
        // Configure permissions for EntityWorldReducer
        bytes4[] memory reducerSelectors = new bytes4[](1);
        reducerSelectors[0] = EntityWorldReducer.setDependencies.selector;
        accessManager.setTargetFunctionRole(
            address(entityWorldReducer),
            reducerSelectors,
            accessManager.ADMIN_ROLE()
        );
        bytes4[] memory spawnerReducerSelectors = new bytes4[](1);
        spawnerReducerSelectors[0] = EntityWorldReducer.spawnEntity.selector;
        accessManager.setTargetFunctionRole(
            address(entityWorldReducer),
            spawnerReducerSelectors,
            accessManager.SPAWNER_ROLE()
        );
        // Grant SPAWNER_ROLE to world1 for reducer
        accessManager.grantRole(
            accessManager.SPAWNER_ROLE(),
            address(world1),
            0
        );
        // Configure permissions for WorldRegistry functions
        bytes4[] memory worldManagerSelectors = new bytes4[](2);
        worldManagerSelectors[0] = WorldRegistry.registerWorld.selector;
        worldManagerSelectors[1] = WorldRegistry.unregisterWorld.selector;
        accessManager.setTargetFunctionRole(
            address(worldRegistry),
            worldManagerSelectors,
            accessManager.WORLD_MANAGER_ROLE()
        );
        // Configure ADMIN role for WorldRegistry dependencies
        bytes4[] memory adminSelectors = new bytes4[](1);
        adminSelectors[0] = WorldRegistry.setDependencies.selector;
        accessManager.setTargetFunctionRole(
            address(worldRegistry),
            adminSelectors,
            accessManager.ADMIN_ROLE()
        );
        vm.stopPrank();

        // Connect registries and reducer
        vm.prank(admin);
        spawnRegistry.setDependencies(worldRegistry);

        // Register worlds
        vm.prank(spawnManager);
        worldRegistry.registerWorld(world1);
        vm.prank(spawnManager);
        worldRegistry.registerWorld(world2);
    }

    // Test basic spawn world management
    function test_AddRemoveSpawnWorld() public {
        uint256 worldId = worldRegistry.getWorldId(world1);

        // Add spawn world
        vm.prank(spawnManager);
        spawnRegistry.addValidSpawnWorld(worldId);
        assertTrue(spawnRegistry.validSpawnWorlds(worldId));

        // Remove spawn world
        vm.prank(spawnManager);
        spawnRegistry.removeValidSpawnWorld(worldId);
        assertFalse(spawnRegistry.validSpawnWorlds(worldId));
    }

    // Test permission checks for spawn world management
    function test_OnlySpawnManagerCanManageSpawnWorlds() public {
        uint256 worldId = worldRegistry.getWorldId(world1);

        // Non-manager cannot add spawn world
        vm.expectRevert(); // AccessManager will revert with unauthorized error
        vm.prank(nonManager);
        spawnRegistry.addValidSpawnWorld(worldId);

        // Manager can add spawn world
        vm.prank(spawnManager);
        spawnRegistry.addValidSpawnWorld(worldId);
    }

    // Test adding a world that's already a valid spawn world
    function test_CannotAddAlreadyValidSpawnWorld() public {
        uint256 worldId = worldRegistry.getWorldId(world1);

        // Add world as valid spawn point
        vm.prank(spawnManager);
        spawnRegistry.addValidSpawnWorld(worldId);

        // Try to add again
        vm.expectRevert(RegistryUtils.AlreadyRegistered.selector);
        vm.prank(spawnManager);
        spawnRegistry.addValidSpawnWorld(worldId);
    }

    // Test removing a world that's not a valid spawn world
    function test_CannotRemoveInvalidSpawnWorld() public {
        uint256 worldId = worldRegistry.getWorldId(world1);

        // Try to remove a world that hasn't been added
        vm.expectRevert(RegistryUtils.NotRegistered.selector);
        vm.prank(spawnManager);
        spawnRegistry.removeValidSpawnWorld(worldId);
    }

    // Test spawning through reducer
    function test_SpawnEntityThroughReducer() public {
        uint256 worldId = worldRegistry.getWorldId(world1);
        vm.prank(spawnManager);
        spawnRegistry.addValidSpawnWorld(worldId);

        vm.prank(address(world1));
        entityWorldReducer.spawnEntity(gameEntity1, worldId);
        assertEq(entityWorldDatastore.getEntityWorldId(gameEntity1), worldId);
    }

    function test_CannotSpawnThroughReducer_InvalidWorld() public {
        uint256 worldId = worldRegistry.getWorldId(world1);
        vm.prank(spawnManager);
        spawnRegistry.addValidSpawnWorld(worldId);

        vm.prank(address(world1));
        vm.expectRevert(IEntityWorldReducer.InvalidWorld.selector);
        entityWorldReducer.spawnEntity(gameEntity1, worldId);
    }

    function test_CannotSpawnThroughReducer_AlreadyInWorld() public {
        uint256 worldId = worldRegistry.getWorldId(world1);
        vm.prank(spawnManager);
        spawnRegistry.addValidSpawnWorld(worldId);

        vm.prank(address(world1));
        entityWorldReducer.spawnEntity(gameEntity1, worldId);
        vm.prank(address(world1));
        vm.expectRevert(IEntityWorldReducer.EntityAlreadyInWorld.selector);
        entityWorldReducer.spawnEntity(gameEntity1, worldId);
    }

    function test_OnlyReducerSpawnerCanSpawn() public {
        uint256 worldId = worldRegistry.getWorldId(world1);
        vm.prank(spawnManager);
        spawnRegistry.addValidSpawnWorld(worldId);

        vm.prank(nonManager);
        vm.expectRevert();
        entityWorldReducer.spawnEntity(gameEntity1, worldId);
    }

    // Test event emissions
    function test_EventEmissions() public {
        uint256 worldId = worldRegistry.getWorldId(world1);

        // Test SpawnWorldAdded event
        vm.expectEmit(true, true, true, true);
        emit SpawnRegistry.SpawnWorldAdded(worldId);
        vm.prank(spawnManager);
        spawnRegistry.addValidSpawnWorld(worldId);

        // Test SpawnWorldRemoved event
        vm.expectEmit(true, true, true, true);
        emit SpawnRegistry.SpawnWorldRemoved(worldId);
        vm.prank(spawnManager);
        spawnRegistry.removeValidSpawnWorld(worldId);
    }

    // Invariant test for spawn world consistency
    function test_Invariant_SpawnWorldConsistency() public {
        uint256 worldId = worldRegistry.getWorldId(world1);

        // Add and remove spawn world multiple times
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(spawnManager);
            spawnRegistry.addValidSpawnWorld(worldId);
            assertTrue(spawnRegistry.validSpawnWorlds(worldId));

            vm.prank(spawnManager);
            spawnRegistry.removeValidSpawnWorld(worldId);
            assertFalse(spawnRegistry.validSpawnWorlds(worldId));
        }
    }
}
