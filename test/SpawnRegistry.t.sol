// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {SpawnRegistry} from "../src/registries/SpawnRegistry.sol";
import {WorldRegistry} from "../src/registries/WorldRegistry.sol";
import {IGameWorld} from "../src/interfaces/IGameWorld.sol";
import {MockEntityNFT} from "./mocks/MockEntityNFT.sol";
import {MockGameWorld} from "./mocks/MockGameWorld.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {RegistryUtils} from "../src/libraries/RegistryUtils.sol";
import {IEntityNFT} from "../src/interfaces/IEntityNFT.sol";
import {GameEntity} from "../src/structs/GameEntity.sol";

contract SpawnRegistryTest is Test {
    SpawnRegistry public spawnRegistry;
    WorldRegistry public worldRegistry;
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
        // Deploy contracts
        worldRegistry = new WorldRegistry();
        spawnRegistry = new SpawnRegistry();

        // Create test addresses
        admin = makeAddr("admin");
        spawnManager = makeAddr("spawnManager");
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
            spawnRegistry.getRoleMember(spawnRegistry.DEFAULT_ADMIN_ROLE(), 0)
        );
        spawnRegistry.grantRole(
            spawnRegistry.SPAWN_MANAGER_ROLE(),
            spawnManager
        );
        vm.stopPrank();

        // Initialize registries
        vm.startPrank(
            worldRegistry.getRoleMember(worldRegistry.DEFAULT_ADMIN_ROLE(), 0)
        );
        worldRegistry.setSpawnRegistry(spawnRegistry);
        worldRegistry.registerWorld(world1);
        worldRegistry.registerWorld(world2);
        vm.stopPrank();

        // Set world registry in spawn registry
        vm.startPrank(
            spawnRegistry.getRoleMember(spawnRegistry.DEFAULT_ADMIN_ROLE(), 0)
        );
        spawnRegistry.setWorldRegistry(worldRegistry);
        vm.stopPrank();
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
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonManager,
                spawnRegistry.SPAWN_MANAGER_ROLE()
            )
        );
        vm.prank(nonManager);
        spawnRegistry.addValidSpawnWorld(worldId);

        // Manager can add spawn world
        vm.prank(spawnManager);
        spawnRegistry.addValidSpawnWorld(worldId);
    }

    // Test entityNFT spawning
    function test_SpawnEntity() public {
        uint256 worldId = worldRegistry.getWorldId(world1);

        // Add world as valid spawn point
        vm.prank(spawnManager);
        spawnRegistry.addValidSpawnWorld(worldId);

        // Spawn entityNFT
        vm.prank(spawnManager);
        spawnRegistry.spawnEntity(gameEntity1, worldId);

        assertEq(worldRegistry.getEntityWorldId(gameEntity1), worldId);
    }

    // Test spawning in invalid world
    function test_CannotSpawnInInvalidWorld() public {
        uint256 worldId = worldRegistry.getWorldId(world1);

        vm.expectRevert(RegistryUtils.InvalidWorld.selector);
        vm.prank(spawnManager);
        spawnRegistry.spawnEntity(gameEntity1, worldId);
    }

    // Test spawning already spawned entityNFT
    function test_CannotSpawnExistingEntity() public {
        uint256 worldId = worldRegistry.getWorldId(world1);

        // Add world as valid spawn point
        vm.prank(spawnManager);
        spawnRegistry.addValidSpawnWorld(worldId);

        // Spawn entityNFT
        vm.prank(spawnManager);
        spawnRegistry.spawnEntity(gameEntity1, worldId);

        // Try to spawn again
        vm.expectRevert(RegistryUtils.EntityAlreadyInWorld.selector);
        vm.prank(spawnManager);
        spawnRegistry.spawnEntity(gameEntity1, worldId);
    }

    // Fuzzing test for multiple spawns
    function testFuzz_MultipleSpawns(uint256 seed) public {
        // Limit the number of entityNFTs to prevent stack too deep
        uint256 numEntityNFTs = bound((seed % 10) + 1, 1, 10);
        uint256 worldId = worldRegistry.getWorldId(world1);

        // Add world as valid spawn point
        vm.prank(spawnManager);
        spawnRegistry.addValidSpawnWorld(worldId);

        // Create and spawn entityNFTs
        for (uint256 i = 0; i < numEntityNFTs; i++) {
            MockEntityNFT entityNFT = new MockEntityNFT();
            vm.prank(spawnManager);
            GameEntity memory gameEntity = GameEntity({
                entityNFT: entityNFT,
                entityId: i + 1
            });
            spawnRegistry.spawnEntity(gameEntity, worldId);
            assertEq(worldRegistry.getEntityWorldId(gameEntity), worldId);
        }
    }

    // Differential test between spawn and non-spawn worlds
    function test_DifferentialSpawnWorlds() public {
        uint256 world1Id = worldRegistry.getWorldId(world1);
        uint256 world2Id = worldRegistry.getWorldId(world2);

        // Only add world1 as valid spawn point
        vm.prank(spawnManager);
        spawnRegistry.addValidSpawnWorld(world1Id);

        // Can spawn in world1
        vm.prank(spawnManager);
        spawnRegistry.spawnEntity(gameEntity1, world1Id);

        // Cannot spawn in world2
        vm.expectRevert(RegistryUtils.InvalidWorld.selector);
        vm.prank(spawnManager);
        spawnRegistry.spawnEntity(gameEntity3, world2Id);
    }

    // Test event emissions
    function test_EventEmissions() public {
        uint256 worldId = worldRegistry.getWorldId(world1);

        // Test SpawnWorldAdded event
        vm.expectEmit(true, true, true, true);
        emit SpawnRegistry.SpawnWorldAdded(worldId);
        vm.prank(spawnManager);
        spawnRegistry.addValidSpawnWorld(worldId);

        // Test EntitySpawned event
        vm.expectEmit(true, true, true, true);
        emit SpawnRegistry.EntitySpawned(gameEntity1, worldId);
        vm.prank(spawnManager);
        spawnRegistry.spawnEntity(gameEntity1, worldId);
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

    // Invariant test for entityNFT spawn state
    function test_Invariant_EntitySpawnState() public {
        uint256 worldId = worldRegistry.getWorldId(world1);

        // Add world as valid spawn point
        vm.prank(spawnManager);
        spawnRegistry.addValidSpawnWorld(worldId);

        // Spawn entityNFT
        vm.prank(spawnManager);
        spawnRegistry.spawnEntity(gameEntity1, worldId);

        // EntityNFT should stay in the same world until moved by world
        assertEq(worldRegistry.getEntityWorldId(gameEntity1), worldId);
    }
}
