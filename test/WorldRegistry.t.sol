// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {WorldRegistry} from "../src/registries/WorldRegistry.sol";
import {SpawnRegistry} from "../src/registries/SpawnRegistry.sol";
import {MockEntityNFT} from "./mocks/MockEntityNFT.sol";
import {MockGameWorld} from "./mocks/MockGameWorld.sol";
import {TigerHuntAccessManager} from "../src/access/TigerHuntAccessManager.sol";
import {IWorldRegistry} from "../src/interfaces/IWorldRegistry.sol";
import {RegistryUtils} from "../src/libraries/RegistryUtils.sol";
import {GameEntity} from "../src/structs/GameEntity.sol";

contract WorldRegistryTest is Test {
    WorldRegistry public worldRegistry;
    SpawnRegistry public spawnRegistry;
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
    address public worldManager;
    address public nonManager;
    address public admin;

    function setUp() public {
        // Create test addresses
        admin = makeAddr("admin");
        worldManager = makeAddr("worldManager");
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

        // Setup permissions
        vm.startPrank(admin);

        // Configure permissions for functions
        bytes4[] memory worldManagerSelectors = new bytes4[](2);
        worldManagerSelectors[0] = WorldRegistry.registerWorld.selector;
        worldManagerSelectors[1] = WorldRegistry.unregisterWorld.selector;
        accessManager.setTargetFunctionRole(
            address(worldRegistry),
            worldManagerSelectors,
            accessManager.WORLD_MANAGER_ROLE()
        );

        bytes4[] memory spawnerSelectors = new bytes4[](1);
        spawnerSelectors[0] = WorldRegistry.spawnEntity.selector;
        accessManager.setTargetFunctionRole(
            address(worldRegistry),
            spawnerSelectors,
            accessManager.SPAWNER_ROLE()
        );

        bytes4[] memory adminSelectors = new bytes4[](1);
        adminSelectors[0] = WorldRegistry.setDependencies.selector;
        accessManager.setTargetFunctionRole(
            address(worldRegistry),
            adminSelectors,
            accessManager.ADMIN_ROLE()
        );

        // Grant roles to addresses
        accessManager.grantRole(
            accessManager.WORLD_MANAGER_ROLE(),
            worldManager,
            0
        );
        accessManager.grantRole(accessManager.SPAWNER_ROLE(), address(this), 0);
        accessManager.grantRole(
            accessManager.SPAWNER_ROLE(),
            address(world1),
            0
        );

        // Set up spawn registry permissions
        bytes4[] memory spawnManagerSelectors = new bytes4[](2);
        spawnManagerSelectors[0] = SpawnRegistry.addValidSpawnWorld.selector;
        spawnManagerSelectors[1] = SpawnRegistry.removeValidSpawnWorld.selector;
        accessManager.setTargetFunctionRole(
            address(spawnRegistry),
            spawnManagerSelectors,
            accessManager.SPAWN_MANAGER_ROLE()
        );

        bytes4[] memory spawnAdminSelectors = new bytes4[](1);
        spawnAdminSelectors[0] = SpawnRegistry.setDependencies.selector;
        accessManager.setTargetFunctionRole(
            address(spawnRegistry),
            spawnAdminSelectors,
            accessManager.ADMIN_ROLE()
        );

        accessManager.grantRole(
            accessManager.SPAWN_MANAGER_ROLE(),
            worldManager,
            0
        );

        vm.stopPrank();

        // Initialize registries
        vm.prank(admin);
        worldRegistry.setDependencies(spawnRegistry);

        vm.prank(admin);
        spawnRegistry.setDependencies(worldRegistry);

        // Register worlds
        vm.prank(worldManager);
        worldRegistry.registerWorld(world1);
        vm.prank(worldManager);
        worldRegistry.registerWorld(world2);
    }

    // Test basic world registration
    function test_RegisterUnregisterWorld() public {
        // Unregister world
        vm.prank(worldManager);
        worldRegistry.unregisterWorld(world1);
        assertFalse(worldRegistry.isWorldRegistered(world1));

        // Re-register world
        vm.prank(worldManager);
        worldRegistry.registerWorld(world1);
        assertTrue(worldRegistry.isWorldRegistered(world1));
    }

    // Test permission checks for world management
    function test_OnlyWorldManagerCanManageWorlds() public {
        // Non-manager cannot unregister world
        vm.expectRevert(); // AccessManager will revert with unauthorized error
        vm.prank(nonManager);
        worldRegistry.unregisterWorld(world1);

        // Manager can unregister world
        vm.prank(worldManager);
        worldRegistry.unregisterWorld(world1);
    }

    // Test entity spawning
    function test_SpawnEntity() public {
        uint256 world1Id = worldRegistry.getWorldId(world1);

        // Add world as valid spawn point
        vm.prank(worldManager);
        spawnRegistry.addValidSpawnWorld(world1Id);

        // Spawn entity
        vm.prank(address(world1));
        worldRegistry.spawnEntity(gameEntity1, world1Id);
        assertEq(worldRegistry.getEntityWorldId(gameEntity1), world1Id);
    }

    // Test entity movement between worlds
    function test_MoveEntityBetweenWorlds() public {
        uint256 world1Id = worldRegistry.getWorldId(world1);
        uint256 world2Id = worldRegistry.getWorldId(world2);

        // Add worlds as valid spawn points
        vm.prank(worldManager);
        spawnRegistry.addValidSpawnWorld(world1Id);
        vm.prank(worldManager);
        spawnRegistry.addValidSpawnWorld(world2Id);

        // Spawn entity in world1
        vm.prank(address(world1));
        worldRegistry.spawnEntity(gameEntity1, world1Id);

        // Move entity to world2 - must be called by world1
        vm.prank(address(world1));
        worldRegistry.updateEntityWorld(gameEntity1, world2Id);

        assertEq(worldRegistry.getEntityWorldId(gameEntity1), world2Id);
    }

    // Test moving entity to invalid world
    function test_CannotMoveToInvalidWorld() public {
        uint256 world1Id = worldRegistry.getWorldId(world1);
        uint256 invalidWorldId = 999;

        // Add world1 as valid spawn point
        vm.prank(worldManager);
        spawnRegistry.addValidSpawnWorld(world1Id);

        // Spawn entity in world1
        vm.prank(address(world1));
        worldRegistry.spawnEntity(gameEntity1, world1Id);

        // Try to move to invalid world - must be called by world1
        vm.expectRevert(RegistryUtils.InvalidWorld.selector);
        vm.prank(address(world1));
        worldRegistry.updateEntityWorld(gameEntity1, invalidWorldId);
    }

    // Test unauthorized spawning
    function test_OnlySpawnerCanSpawn() public {
        uint256 world1Id = worldRegistry.getWorldId(world1);

        // Add world as valid spawn point
        vm.prank(worldManager);
        spawnRegistry.addValidSpawnWorld(world1Id);

        // Non-spawner cannot spawn
        vm.expectRevert(); // AccessManager will revert with unauthorized error
        vm.prank(nonManager);
        worldRegistry.spawnEntity(gameEntity1, world1Id);
    }

    // Test spawning in invalid world
    function test_CannotSpawnInInvalidWorld() public {
        uint256 world1Id = worldRegistry.getWorldId(world1);

        vm.expectRevert(RegistryUtils.InvalidWorld.selector);
        worldRegistry.spawnEntity(gameEntity1, world1Id);
    }

    // Test spawning already spawned entity
    function test_CannotSpawnExistingEntity() public {
        uint256 world1Id = worldRegistry.getWorldId(world1);

        // Add world as valid spawn point
        vm.prank(worldManager);
        spawnRegistry.addValidSpawnWorld(world1Id);

        // Spawn entity
        vm.prank(address(world1));
        worldRegistry.spawnEntity(gameEntity1, world1Id);

        // Try to spawn already spawned entity
        vm.expectRevert(RegistryUtils.EntityAlreadyInWorld.selector);
        vm.prank(address(world1));
        worldRegistry.spawnEntity(gameEntity1, world1Id);
    }

    // Test event emissions
    function test_EventEmissions() public {
        // First unregister world1 so we can test registration
        uint256 worldId = worldRegistry.getWorldId(world1);
        vm.prank(worldManager);
        worldRegistry.unregisterWorld(world1);

        // Test WorldRegistered event
        vm.expectEmit(true, true, true, true);
        emit IWorldRegistry.WorldRegistered(worldId + 2, world1);
        vm.prank(worldManager);
        worldRegistry.registerWorld(world1);

        // Test WorldUnregistered event
        vm.expectEmit(true, true, true, true);
        emit IWorldRegistry.WorldUnregistered(worldId + 2, world1);
        vm.prank(worldManager);
        worldRegistry.unregisterWorld(world1);

        // Re-register world1 for entity spawning
        vm.prank(worldManager);
        worldRegistry.registerWorld(world1);

        // Get the new world ID after re-registration
        uint256 newWorldId = worldRegistry.getWorldId(world1);
        vm.prank(worldManager);
        spawnRegistry.addValidSpawnWorld(newWorldId);

        // Test EntityWorldChanged event for spawning
        vm.expectEmit(true, true, true, true);
        emit IWorldRegistry.EntityWorldChanged(gameEntity1, 0, newWorldId);
        vm.prank(address(world1));
        worldRegistry.spawnEntity(gameEntity1, newWorldId);

        // Test EntityWorldChanged event for moving
        uint256 world2Id = worldRegistry.getWorldId(world2);
        vm.expectEmit(true, true, true, true);
        emit IWorldRegistry.EntityWorldChanged(
            gameEntity1,
            newWorldId,
            world2Id
        );
        vm.prank(address(world1));
        worldRegistry.updateEntityWorld(gameEntity1, world2Id);
    }

    // Invariant test for world registration consistency
    function test_Invariant_WorldRegistrationConsistency() public {
        // Register and unregister world multiple times
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(worldManager);
            worldRegistry.unregisterWorld(world1);
            assertFalse(worldRegistry.isWorldRegistered(world1));

            vm.prank(worldManager);
            worldRegistry.registerWorld(world1);
            assertTrue(worldRegistry.isWorldRegistered(world1));
        }
    }

    // Invariant test for entity world assignment
    function test_Invariant_EntityWorldAssignment() public {
        uint256 world1Id = worldRegistry.getWorldId(world1);
        uint256 world2Id = worldRegistry.getWorldId(world2);

        vm.prank(worldManager);
        spawnRegistry.addValidSpawnWorld(world1Id);
        vm.prank(worldManager);
        spawnRegistry.addValidSpawnWorld(world2Id);

        // Spawn entity in world1
        vm.prank(address(world1));
        worldRegistry.spawnEntity(gameEntity1, world1Id);

        // Move entity between worlds multiple times
        for (uint256 i = 0; i < 3; i++) {
            // Move to world2 - must be called by world1
            vm.prank(address(world1));
            worldRegistry.updateEntityWorld(gameEntity1, world2Id);
            assertEq(worldRegistry.getEntityWorldId(gameEntity1), world2Id);

            // Move back to world1 - must be called by world2
            vm.prank(address(world2));
            worldRegistry.updateEntityWorld(gameEntity1, world1Id);
            assertEq(worldRegistry.getEntityWorldId(gameEntity1), world1Id);
        }
    }

    // Test getWorldFromWorldId functionality
    function test_GetWorldFromWorldId() public view {
        uint256 world1Id = worldRegistry.getWorldId(world1);
        uint256 world2Id = worldRegistry.getWorldId(world2);

        // Test valid world ID lookups
        assertEq(
            address(worldRegistry.getWorldFromWorldId(world1Id)),
            address(world1)
        );
        assertEq(
            address(worldRegistry.getWorldFromWorldId(world2Id)),
            address(world2)
        );

        // Test non-existent world ID lookup
        uint256 nonExistentWorldId = 999;
        assertEq(
            address(worldRegistry.getWorldFromWorldId(nonExistentWorldId)),
            address(0)
        );
    }

    // Test getAreEntitiesInSameWorld functionality
    function test_GetAreEntitiesInSameWorld() public {
        uint256 world1Id = worldRegistry.getWorldId(world1);
        uint256 world2Id = worldRegistry.getWorldId(world2);

        vm.prank(worldManager);
        spawnRegistry.addValidSpawnWorld(world1Id);
        vm.prank(worldManager);
        spawnRegistry.addValidSpawnWorld(world2Id);

        // Spawn entities in different worlds
        vm.prank(address(world1));
        worldRegistry.spawnEntity(gameEntity1, world1Id);
        vm.prank(address(world2));
        worldRegistry.spawnEntity(gameEntity3, world2Id);

        // Entities in different worlds
        assertFalse(
            worldRegistry.getAreEntitiesInSameWorld(gameEntity1, gameEntity3)
        );

        // Spawn another entity in world1
        vm.prank(address(world1));
        worldRegistry.spawnEntity(gameEntity2, world1Id);

        // Entities in same world
        assertTrue(
            worldRegistry.getAreEntitiesInSameWorld(gameEntity1, gameEntity2)
        );

        // Unspawned entity comparison
        assertFalse(
            worldRegistry.getAreEntitiesInSameWorld(gameEntity1, gameEntity4)
        );
        assertFalse(
            worldRegistry.getAreEntitiesInSameWorld(gameEntity4, gameEntity1)
        );
    }

    // Test setSpawnRegistry functionality
    function test_SetSpawnRegistry() public {
        // Deploy a new spawn registry
        SpawnRegistry newSpawnRegistry = new SpawnRegistry(
            address(accessManager)
        );

        // Only admin can set spawn registry
        vm.prank(nonManager);
        vm.expectRevert();
        worldRegistry.setDependencies(newSpawnRegistry);

        // Admin can set spawn registry
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit WorldRegistry.SpawnRegistrySet(newSpawnRegistry);
        worldRegistry.setDependencies(newSpawnRegistry);

        // Verify spawn registry was set
        assertEq(
            address(worldRegistry.spawnRegistry()),
            address(newSpawnRegistry)
        );
    }

    // Test unauthorized entity world update
    function test_UnauthorizedEntityWorldUpdate() public {
        uint256 world1Id = worldRegistry.getWorldId(world1);
        uint256 world2Id = worldRegistry.getWorldId(world2);

        vm.prank(worldManager);
        spawnRegistry.addValidSpawnWorld(world1Id);

        // Spawn entity in world1
        vm.prank(address(world1));
        worldRegistry.spawnEntity(gameEntity1, world1Id);

        // Try to move entity from wrong world (world2)
        vm.expectRevert(RegistryUtils.Unauthorized.selector);
        vm.prank(address(world2));
        worldRegistry.updateEntityWorld(gameEntity1, world2Id);

        // Try to move entity from unrelated address
        vm.expectRevert(RegistryUtils.Unauthorized.selector);
        vm.prank(nonManager);
        worldRegistry.updateEntityWorld(gameEntity1, world2Id);
    }

    // Test entity not in world error
    function test_EntityNotInWorld() public {
        uint256 world1Id = worldRegistry.getWorldId(world1);

        // Try to update entity that isn't in any world
        vm.expectRevert(RegistryUtils.EntityNotInWorld.selector);
        vm.prank(address(world1));
        worldRegistry.updateEntityWorld(gameEntity1, world1Id);
    }

    // Test unregistering a world that has entities
    function test_UnregisterWorldWithEntities() public {
        uint256 world1Id = worldRegistry.getWorldId(world1);

        vm.prank(worldManager);
        spawnRegistry.addValidSpawnWorld(world1Id);

        // Spawn entity in world1
        vm.prank(address(world1));
        worldRegistry.spawnEntity(gameEntity1, world1Id);

        // Unregister world1
        vm.prank(worldManager);
        worldRegistry.unregisterWorld(world1);

        // Verify world is no longer registered
        assertFalse(worldRegistry.isWorldRegistered(world1));

        // Entity's world ID remains, but the world is no longer valid
        assertEq(worldRegistry.getEntityWorldId(gameEntity1), world1Id);
        assertEq(
            address(worldRegistry.getWorldFromWorldId(world1Id)),
            address(0)
        );
    }

    // Test registering already registered world
    function test_RegisterAlreadyRegisteredWorld() public {
        vm.prank(worldManager);
        vm.expectRevert(RegistryUtils.AlreadyRegistered.selector);
        worldRegistry.registerWorld(world1);
    }

    // Test unregistering non-registered world
    function test_UnregisterNonRegisteredWorld() public {
        MockGameWorld newWorld = new MockGameWorld();

        vm.prank(worldManager);
        vm.expectRevert(RegistryUtils.NotRegistered.selector);
        worldRegistry.unregisterWorld(newWorld);
    }

    // Test spawning entity into a world from a different world
    function test_SpawnEntityFromDifferentWorld() public {
        uint256 world1Id = worldRegistry.getWorldId(world1);

        vm.prank(worldManager);
        spawnRegistry.addValidSpawnWorld(world1Id);

        // Try to spawn entity in world1 from world2
        // Should fail because world2 is not world1
        vm.expectRevert(RegistryUtils.Unauthorized.selector);
        vm.prank(address(world2));
        worldRegistry.spawnEntity(gameEntity1, world1Id);
    }
}
