// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {WorldRegistry} from "../src/registries/WorldRegistry.sol";
import {SpawnRegistry} from "../src/registries/SpawnRegistry.sol";
import {MockEntityNFT} from "./mocks/MockEntityNFT.sol";
import {MockGameWorld} from "./mocks/MockGameWorld.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IWorldRegistry} from "../src/interfaces/IWorldRegistry.sol";
import {RegistryUtils} from "../src/libraries/RegistryUtils.sol";
import {GameEntity} from "../src/structs/GameEntity.sol";

contract WorldRegistryTest is Test {
    WorldRegistry public worldRegistry;
    SpawnRegistry public spawnRegistry;
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
        // Deploy contracts
        worldRegistry = new WorldRegistry();
        spawnRegistry = new SpawnRegistry();

        // Create test addresses
        admin = makeAddr("admin");
        worldManager = makeAddr("worldManager");
        nonManager = makeAddr("nonManager");
        entityHolder = makeAddr("entityHolder");

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

        // Setup roles
        vm.startPrank(
            worldRegistry.getRoleMember(worldRegistry.DEFAULT_ADMIN_ROLE(), 0)
        );
        worldRegistry.grantRole(
            worldRegistry.WORLD_MANAGER_ROLE(),
            worldManager
        );
        worldRegistry.grantRole(worldRegistry.SPAWNER_ROLE(), address(this));
        worldRegistry.grantRole(worldRegistry.SPAWNER_ROLE(), address(world1));
        vm.stopPrank();

        // Initialize registries
        worldRegistry.setSpawnRegistry(spawnRegistry);
        spawnRegistry.setWorldRegistry(worldRegistry);

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
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonManager,
                worldRegistry.WORLD_MANAGER_ROLE()
            )
        );
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
        vm.startPrank(
            spawnRegistry.getRoleMember(spawnRegistry.DEFAULT_ADMIN_ROLE(), 0)
        );
        spawnRegistry.grantRole(
            spawnRegistry.SPAWN_MANAGER_ROLE(),
            worldManager
        );
        vm.stopPrank();

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
        vm.startPrank(
            spawnRegistry.getRoleMember(spawnRegistry.DEFAULT_ADMIN_ROLE(), 0)
        );
        spawnRegistry.grantRole(
            spawnRegistry.SPAWN_MANAGER_ROLE(),
            worldManager
        );
        vm.stopPrank();

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
        vm.startPrank(
            spawnRegistry.getRoleMember(spawnRegistry.DEFAULT_ADMIN_ROLE(), 0)
        );
        spawnRegistry.grantRole(
            spawnRegistry.SPAWN_MANAGER_ROLE(),
            worldManager
        );
        vm.stopPrank();

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
        vm.startPrank(
            spawnRegistry.getRoleMember(spawnRegistry.DEFAULT_ADMIN_ROLE(), 0)
        );
        spawnRegistry.grantRole(
            spawnRegistry.SPAWN_MANAGER_ROLE(),
            worldManager
        );
        vm.stopPrank();

        vm.prank(worldManager);
        spawnRegistry.addValidSpawnWorld(world1Id);

        // Non-spawner cannot spawn
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonManager,
                worldRegistry.SPAWNER_ROLE()
            )
        );
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
        vm.startPrank(
            spawnRegistry.getRoleMember(spawnRegistry.DEFAULT_ADMIN_ROLE(), 0)
        );
        spawnRegistry.grantRole(
            spawnRegistry.SPAWN_MANAGER_ROLE(),
            worldManager
        );
        vm.stopPrank();

        vm.prank(worldManager);
        spawnRegistry.addValidSpawnWorld(world1Id);

        // Spawn entity
        vm.prank(address(world1));
        worldRegistry.spawnEntity(gameEntity1, world1Id);

        // Try to spawn again
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

        // Test EntityWorldChanged event
        vm.startPrank(
            spawnRegistry.getRoleMember(spawnRegistry.DEFAULT_ADMIN_ROLE(), 0)
        );
        spawnRegistry.grantRole(
            spawnRegistry.SPAWN_MANAGER_ROLE(),
            worldManager
        );
        vm.stopPrank();

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

        // Add worlds as valid spawn points
        vm.startPrank(
            spawnRegistry.getRoleMember(spawnRegistry.DEFAULT_ADMIN_ROLE(), 0)
        );
        spawnRegistry.grantRole(
            spawnRegistry.SPAWN_MANAGER_ROLE(),
            worldManager
        );
        vm.stopPrank();

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
}
