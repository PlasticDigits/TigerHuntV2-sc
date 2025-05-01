// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {IGameWorld} from "../interfaces/IGameWorld.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {GameEntity} from "../structs/GameEntity.sol";
import {CoordinatePacking} from "../libraries/CoordinatePacking.sol";
import {GameEntityUtils} from "../libraries/GameEntityUtils.sol";
import {IEntityNFT} from "../interfaces/IEntityNFT.sol";
import {IWorldRegistry} from "../interfaces/IWorldRegistry.sol";

contract GameWorldSquare is IGameWorld, AccessControl {
    using EnumerableSet for EnumerableSet.UintSet;
    using CoordinatePacking for IGameWorld.PackedTileCoordinate;
    using GameEntityUtils for GameEntity;

    // Role for managing portals
    bytes32 public constant PORTAL_MANAGER_ROLE =
        keccak256("PORTAL_MANAGER_ROLE");
    // Role for the game router
    bytes32 public constant ROUTER_ROLE = keccak256("ROUTER_ROLE");
    // Role for spawning entities
    bytes32 public constant SPAWNER_ROLE = keccak256("SPAWNER_ROLE");

    // World configuration
    uint256 public immutable WORLD_ID;
    uint256 public immutable WORLD_SIZE;
    IWorldRegistry public immutable WORLD_REGISTRY;

    // Entity state tracking
    struct EntityState {
        PackedTileCoordinate tile;
        bool isActive;
    }
    mapping(bytes32 entityRefKey => EntityState state) private _entityStates;
    mapping(bytes32 tileKey => EnumerableSet.UintSet entityRefKeys)
        private _tileToEntityKeys;
    mapping(bytes32 entityRefKey => GameEntity entity) private _gameEntities;

    // Portal management
    struct PortalInfo {
        WorldPortal portal;
        bool isActive;
    }
    mapping(uint256 portalId => PortalInfo portal) private _portals;
    mapping(bytes32 tileKey => uint256 portalId) private _tileToPortalId;
    EnumerableSet.UintSet private _activePortalIds;
    uint256 private _nextPortalId = 1;

    // Events
    event WorldSizeSet(uint256 size);

    constructor(
        uint256 _worldId,
        uint256 _worldSize,
        address _router,
        IWorldRegistry _worldRegistry
    ) {
        WORLD_ID = _worldId;
        WORLD_SIZE = _worldSize;
        WORLD_REGISTRY = _worldRegistry;

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ROUTER_ROLE, _router);
        _grantRole(SPAWNER_ROLE, msg.sender);

        emit WorldSizeSet(_worldSize);
    }

    // ============ Portal Management ============

    function createPortal(
        uint256 _worldId,
        PackedTileCoordinate calldata sourceTile,
        PackedTileCoordinate calldata targetTile,
        uint256 targetWorldId
    ) external onlyRole(PORTAL_MANAGER_ROLE) returns (uint256 portalId) {
        if (_worldId != WORLD_ID) revert InvalidWorldId();
        if (_tileToPortalId[sourceTile.getKey()] != 0)
            revert PortalAlreadyExists();

        // Validate coordinates are within world bounds
        (int64 x, int64 y) = CoordinatePacking.unpackSquareCoordinate(
            sourceTile
        );
        if (uint64(x) >= WORLD_SIZE || uint64(y) >= WORLD_SIZE)
            revert WorldSizeExceeded();

        portalId = _nextPortalId++;
        WorldPortal memory portal = WorldPortal({
            sourceTile: sourceTile,
            targetTile: targetTile,
            targetWorldId: targetWorldId
        });

        _portals[portalId] = PortalInfo({portal: portal, isActive: true});
        _tileToPortalId[sourceTile.getKey()] = portalId;
        _activePortalIds.add(portalId);

        emit PortalCreated(
            portalId,
            WORLD_ID,
            sourceTile,
            targetTile,
            targetWorldId
        );
    }

    function removePortal(
        uint256 portalId,
        uint256 _worldId
    ) external onlyRole(PORTAL_MANAGER_ROLE) {
        if (_worldId != WORLD_ID) revert InvalidWorldId();
        if (!_activePortalIds.contains(portalId)) revert PortalNotFound();

        PortalInfo storage portalInfo = _portals[portalId];
        delete _tileToPortalId[portalInfo.portal.sourceTile.getKey()];
        _activePortalIds.remove(portalId);
        delete _portals[portalId];

        emit PortalRemoved(portalId, WORLD_ID);
    }

    // ============ Entity Movement ============

    function _updateEntityTile(
        bytes32 entityKey,
        bytes32 fromTileKey,
        bytes32 toTileKey
    ) private {
        _tileToEntityKeys[fromTileKey].remove(uint256(entityKey));
        _tileToEntityKeys[toTileKey].add(uint256(entityKey));
    }

    function moveEntity(
        GameEntity calldata gameEntity,
        PackedTileCoordinate calldata fromTile,
        PackedTileCoordinate calldata toTile
    ) external onlyRole(ROUTER_ROLE) {
        // Verify entity is in the correct tile
        bytes32 entityKey = gameEntity.getKey();
        EntityState storage state = _entityStates[entityKey];
        if (!state.isActive) revert EntityNotInWorld();
        if (WORLD_REGISTRY.getEntityWorldId(gameEntity) != WORLD_ID)
            revert EntityNotInWorld();
        if (state.tile.packed != fromTile.packed) revert EntityNotInTile();

        // Validate new coordinates
        (int64 x, int64 y) = CoordinatePacking.unpackSquareCoordinate(toTile);
        if (uint64(x) >= WORLD_SIZE || uint64(y) >= WORLD_SIZE)
            revert WorldSizeExceeded();

        // Update entity state and tile tracking
        bytes32 fromTileKey = fromTile.getKey();
        bytes32 toTileKey = toTile.getKey();
        _updateEntityTile(entityKey, fromTileKey, toTileKey);
        state.tile = toTile;

        emit EntityMoved(gameEntity, fromTile, toTile);
    }

    function transferEntityThroughPortal(
        GameEntity calldata gameEntity,
        WorldPortal calldata portal
    ) external onlyRole(ROUTER_ROLE) {
        // Verify entity is in the correct tile
        bytes32 entityKey = gameEntity.getKey();
        EntityState storage state = _entityStates[entityKey];
        if (!state.isActive) revert EntityNotInWorld();
        if (WORLD_REGISTRY.getEntityWorldId(gameEntity) != WORLD_ID)
            revert EntityNotInWorld();
        if (state.tile.packed != portal.sourceTile.packed)
            revert EntityNotInTile();

        // Update entity state and tile tracking
        bytes32 fromTileKey = portal.sourceTile.getKey();
        _updateEntityTile(entityKey, fromTileKey, bytes32(0)); // Remove from current tile
        state.isActive = false; // Mark as inactive in this world

        // Update world through registry
        WORLD_REGISTRY.updateEntityWorld(gameEntity, portal.targetWorldId);

        // Clear entity state
        _clearEntityState(entityKey);

        emit EntityExitedWorld(gameEntity, WORLD_ID, portal.sourceTile);
        emit EntityEnteredWorld(
            gameEntity,
            portal.targetWorldId,
            portal.targetTile
        );
    }

    // ============ Entity Spawning ============

    function spawnEntity(
        GameEntity calldata gameEntity,
        PackedTileCoordinate calldata tile
    ) external onlyRole(SPAWNER_ROLE) {
        bytes32 entityKey = gameEntity.getKey();
        _gameEntities[entityKey] = gameEntity;
        EntityState storage state = _entityStates[entityKey];
        if (state.isActive) revert EntityAlreadyInWorld();

        // Validate coordinates
        (int64 x, int64 y) = CoordinatePacking.unpackSquareCoordinate(tile);
        if (uint64(x) >= WORLD_SIZE || uint64(y) >= WORLD_SIZE)
            revert WorldSizeExceeded();

        // Set entity state
        state.tile = tile;
        state.isActive = true;

        // Request spawning through WorldRegistry
        WORLD_REGISTRY.spawnEntity(gameEntity, WORLD_ID);

        // Update tile tracking
        bytes32 tileKey = tile.getKey();
        _tileToEntityKeys[tileKey].add(uint256(entityKey));

        emit EntitySpawned(gameEntity, WORLD_ID, tile);
    }

    function despawnEntity(
        GameEntity calldata gameEntity
    ) external onlyRole(SPAWNER_ROLE) {
        bytes32 entityKey = gameEntity.getKey();
        EntityState storage state = _entityStates[entityKey];
        if (!state.isActive) revert EntityNotInWorld();
        if (WORLD_REGISTRY.getEntityWorldId(gameEntity) != WORLD_ID)
            revert EntityNotInWorld();

        // Update tile tracking
        bytes32 tileKey = state.tile.getKey();
        _tileToEntityKeys[tileKey].remove(uint256(entityKey));

        // Update world through registry
        WORLD_REGISTRY.updateEntityWorld(gameEntity, 0);

        // Clear entity state
        _clearEntityState(entityKey);

        emit EntityDespawned(gameEntity, WORLD_ID, state.tile);
    }

    function _clearEntityState(bytes32 entityKey) private {
        EntityState storage state = _entityStates[entityKey];
        delete state.isActive;
        delete state.tile.packed;
        delete state.tile;
        delete _entityStates[entityKey];

        GameEntity storage gameEntity = _gameEntities[entityKey];
        delete gameEntity.entityNFT;
        delete gameEntity.entityId;
        delete _gameEntities[entityKey];
    }

    // ============ View Functions ============

    function getEntityState(
        GameEntity calldata gameEntity
    )
        external
        view
        returns (
            PackedTileCoordinate memory tile,
            uint256 _worldId,
            bool isActive
        )
    {
        EntityState storage state = _entityStates[gameEntity.getKey()];
        return (
            state.tile,
            WORLD_REGISTRY.getEntityWorldId(gameEntity),
            state.isActive
        );
    }

    function getPortal(
        uint256 portalId,
        uint256 _worldId
    ) external view returns (WorldPortal memory) {
        if (_worldId != WORLD_ID) revert InvalidWorldId();
        if (!_activePortalIds.contains(portalId)) revert PortalNotFound();
        return _portals[portalId].portal;
    }

    function getPortalsInWorld(
        uint256 _worldId,
        uint256 startIndex,
        uint256 count
    )
        external
        view
        returns (uint256[] memory portalIds, WorldPortal[] memory portals)
    {
        if (_worldId != WORLD_ID) revert InvalidWorldId();

        uint256 totalPortals = _activePortalIds.length();
        if (startIndex >= totalPortals) {
            return (new uint256[](0), new WorldPortal[](0));
        }

        uint256 endIndex = startIndex + count;
        if (endIndex > totalPortals) {
            endIndex = totalPortals;
        }

        uint256 resultCount = endIndex - startIndex;
        portalIds = new uint256[](resultCount);
        portals = new WorldPortal[](resultCount);

        for (uint256 i = 0; i < resultCount; i++) {
            uint256 portalId = _activePortalIds.at(startIndex + i);
            portalIds[i] = portalId;
            portals[i] = _portals[portalId].portal;
        }
    }

    function isPortalAtTile(
        uint256 _worldId,
        PackedTileCoordinate calldata tile
    ) external view returns (bool, uint256) {
        if (_worldId != WORLD_ID) revert InvalidWorldId();
        uint256 portalId = _tileToPortalId[tile.getKey()];
        return (portalId != 0, portalId);
    }

    // ============ Helper Functions ============

    function packCoordinate(
        int64 x,
        int64 y,
        int128 z
    ) external pure returns (PackedTileCoordinate memory) {
        return CoordinatePacking.packCoordinate(x, y, z);
    }

    function unpackCoordinate(
        PackedTileCoordinate calldata packed
    ) external pure returns (int64 x, int64 y, int128 z) {
        return CoordinatePacking.unpackCoordinate(packed);
    }

    function getNeighboringTiles(
        PackedTileCoordinate calldata tile
    ) external view returns (PackedTileCoordinate[] memory) {
        (int64 x, int64 y) = CoordinatePacking.unpackSquareCoordinate(tile);

        // In a square world, we have 4 neighbors (up, down, left, right)
        PackedTileCoordinate[] memory neighbors = new PackedTileCoordinate[](4);
        uint256 count = 0;

        // Check each direction
        int64[4] memory dx = [int64(0), int64(0), int64(-1), int64(1)];
        int64[4] memory dy = [int64(-1), int64(1), int64(0), int64(0)];

        for (uint256 i = 0; i < 4; i++) {
            int64 newX = x + dx[i];
            int64 newY = y + dy[i];

            // Only add valid coordinates
            if (
                newX >= 0 &&
                uint64(newX) < WORLD_SIZE &&
                newY >= 0 &&
                uint64(newY) < WORLD_SIZE
            ) {
                neighbors[count] = CoordinatePacking.packSquareCoordinate(
                    newX,
                    newY
                );
                count++;
            }
        }

        // Resize array to actual number of neighbors
        PackedTileCoordinate[]
            memory resizedNeighbors = new PackedTileCoordinate[](count);
        for (uint256 i = 0; i < count; i++) {
            resizedNeighbors[i] = neighbors[i];
        }
        return resizedNeighbors;
    }

    function getEntitiesInTile(
        PackedTileCoordinate calldata tile,
        uint256 startIndex,
        uint256 count
    ) external view returns (GameEntity[] memory entities) {
        bytes32 tileKey = tile.getKey();
        EnumerableSet.UintSet storage entityKeys = _tileToEntityKeys[tileKey];
        uint256 totalEntities = entityKeys.length();

        if (startIndex >= totalEntities) {
            return new GameEntity[](0);
        }

        uint256 endIndex = startIndex + count;
        if (endIndex > totalEntities) {
            endIndex = totalEntities;
        }

        uint256 resultCount = endIndex - startIndex;
        entities = new GameEntity[](resultCount);

        for (uint256 i = 0; i < resultCount; i++) {
            bytes32 entityKey = bytes32(entityKeys.at(startIndex + i));
            // Get the stored entity directly from our mapping
            entities[i] = _gameEntities[entityKey];
        }

        return entities;
    }

    function isEntityInTile(
        GameEntity calldata gameEntity,
        PackedTileCoordinate calldata tile
    ) external view returns (bool) {
        EntityState storage state = _entityStates[gameEntity.getKey()];
        return
            state.isActive &&
            WORLD_REGISTRY.getEntityWorldId(gameEntity) == WORLD_ID &&
            state.tile.packed == tile.packed;
    }

    function areEntitiesInSameTile(
        GameEntity calldata gameEntity1,
        GameEntity calldata gameEntity2
    ) external view returns (bool) {
        EntityState storage state1 = _entityStates[gameEntity1.getKey()];
        EntityState storage state2 = _entityStates[gameEntity2.getKey()];

        return
            state1.isActive &&
            state2.isActive &&
            WORLD_REGISTRY.getEntityWorldId(gameEntity1) == WORLD_ID &&
            WORLD_REGISTRY.getEntityWorldId(gameEntity2) == WORLD_ID &&
            state1.tile.packed == state2.tile.packed;
    }

    function getEntityTile(
        GameEntity calldata gameEntity
    ) external view returns (PackedTileCoordinate memory) {
        EntityState storage state = _entityStates[gameEntity.getKey()];
        if (!state.isActive) revert EntityNotInWorld();
        return state.tile;
    }

    function getEntityWorldId(
        GameEntity calldata gameEntity
    ) external view returns (uint256) {
        EntityState storage state = _entityStates[gameEntity.getKey()];
        if (!state.isActive) revert EntityNotInWorld();
        return WORLD_REGISTRY.getEntityWorldId(gameEntity);
    }
}
