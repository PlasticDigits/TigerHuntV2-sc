// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {IGameWorld} from "../interfaces/IGameWorld.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {GameEntity} from "../structs/GameEntity.sol";
import {CoordinatePacking} from "../libraries/CoordinatePacking.sol";
import {GameEntityUtils} from "../libraries/GameEntityUtils.sol";
import {IEntityNFT} from "../interfaces/IEntityNFT.sol";
import {IWorldRegistry} from "../interfaces/IWorldRegistry.sol";
import {IEntityWorldDatastore} from "../interfaces/IEntityWorldDatastore.sol";
import {IEntityWorldReducer} from "../interfaces/IEntityWorldReducer.sol";
import {TigerHuntAccessManager} from "../access/TigerHuntAccessManager.sol";

contract GameWorldSingleTile is IGameWorld, AccessManaged {
    using EnumerableSet for EnumerableSet.UintSet;
    using CoordinatePacking for IGameWorld.PackedTileCoordinate;
    using GameEntityUtils for GameEntity;

    // World configuration
    uint256 public immutable WORLD_ID;
    uint256 public constant WORLD_SIZE = 1; // Single tile world
    IWorldRegistry public immutable WORLD_REGISTRY;
    IEntityWorldDatastore public immutable ENTITY_WORLD_DATASTORE;
    IEntityWorldReducer public immutable ENTITY_WORLD_REDUCER;

    // Single tile coordinate - always (0,0,0)
    PackedTileCoordinate private immutable SINGLE_TILE;
    bytes32 private immutable SINGLE_TILE_KEY;

    // Entity state tracking
    struct EntityState {
        bool isActive;
    }
    mapping(bytes32 entityRefKey => EntityState state) private _entityStates;
    EnumerableSet.UintSet private _worldEntities;
    mapping(bytes32 entityRefKey => GameEntity entity) private _gameEntities;

    // Portal management
    struct PortalInfo {
        WorldPortal portal;
        bool isActive;
    }
    mapping(uint256 portalId => PortalInfo portal) private _portals;
    EnumerableSet.UintSet private _activePortalIds;
    uint256 private _nextPortalId = 1;

    constructor(
        uint256 _worldId,
        IWorldRegistry _worldRegistry,
        IEntityWorldDatastore _entityWorldDatastore,
        IEntityWorldReducer _entityWorldReducer,
        address _accessManager
    ) AccessManaged(_accessManager) {
        WORLD_ID = _worldId;
        WORLD_REGISTRY = _worldRegistry;
        ENTITY_WORLD_DATASTORE = _entityWorldDatastore;
        ENTITY_WORLD_REDUCER = _entityWorldReducer;

        // Initialize the single tile at (0,0,0)
        SINGLE_TILE = CoordinatePacking.packCoordinate(0, 0, 0);
        SINGLE_TILE_KEY = SINGLE_TILE.getKey();
    }

    // ============ Portal Management ============

    function createPortal(
        uint256 _worldId,
        PackedTileCoordinate calldata sourceTile,
        PackedTileCoordinate calldata targetTile,
        uint256 targetWorldId
    ) external restricted returns (uint256 portalId) {
        if (_worldId != WORLD_ID) revert InvalidWorldId();

        // Verify source tile is the single tile
        if (sourceTile.packed != SINGLE_TILE.packed)
            revert InvalidTileCoordinate();

        portalId = _nextPortalId++;
        WorldPortal memory portal = WorldPortal({
            sourceTile: SINGLE_TILE, // Always use the single tile
            targetTile: targetTile,
            targetWorldId: targetWorldId
        });

        _portals[portalId] = PortalInfo({portal: portal, isActive: true});
        _activePortalIds.add(portalId);

        emit PortalCreated(
            portalId,
            WORLD_ID,
            SINGLE_TILE,
            targetTile,
            targetWorldId
        );
    }

    function removePortal(
        uint256 portalId,
        uint256 _worldId
    ) external restricted {
        if (_worldId != WORLD_ID) revert InvalidWorldId();
        if (!_activePortalIds.contains(portalId)) revert PortalNotFound();

        _activePortalIds.remove(portalId);
        delete _portals[portalId];

        emit PortalRemoved(portalId, WORLD_ID);
    }

    // ============ Entity Movement ============

    function moveEntity(
        GameEntity calldata gameEntity,
        PackedTileCoordinate calldata fromTile,
        PackedTileCoordinate calldata toTile
    ) external restricted {
        // In a single-tile world, entities can only move from the single tile to itself
        if (
            fromTile.packed != SINGLE_TILE.packed ||
            toTile.packed != SINGLE_TILE.packed
        ) {
            revert InvalidTileCoordinate();
        }

        // Verify entity is active
        bytes32 entityKey = gameEntity.getKey();
        EntityState storage state = _entityStates[entityKey];
        if (!state.isActive) revert EntityNotInWorld();
        if (ENTITY_WORLD_DATASTORE.getEntityWorldId(gameEntity) != WORLD_ID)
            revert EntityNotInWorld();

        // No movement occurs, but we emit the event for tracking
        emit EntityMoved(gameEntity, SINGLE_TILE, SINGLE_TILE);
    }

    function transferEntityThroughPortal(
        GameEntity calldata gameEntity,
        WorldPortal calldata portal
    ) external restricted {
        // Verify portal is valid
        if (portal.sourceTile.packed != SINGLE_TILE.packed)
            revert InvalidTileCoordinate();

        // Verify entity is active
        bytes32 entityKey = gameEntity.getKey();
        EntityState storage state = _entityStates[entityKey];
        if (!state.isActive) revert EntityNotInWorld();
        if (ENTITY_WORLD_DATASTORE.getEntityWorldId(gameEntity) != WORLD_ID)
            revert EntityNotInWorld();

        // Mark entity as inactive in this world
        state.isActive = false;
        _worldEntities.remove(uint256(entityKey));

        // Update world through the reducer
        ENTITY_WORLD_REDUCER.moveEntityBetweenWorlds(
            gameEntity,
            portal.targetWorldId
        );

        // Clear entity state
        _clearEntityState(entityKey);

        emit EntityExitedWorld(gameEntity, WORLD_ID, SINGLE_TILE);
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
    ) external restricted {
        // Ensure the tile is the single tile
        if (tile.packed != SINGLE_TILE.packed) revert InvalidTileCoordinate();

        bytes32 entityKey = gameEntity.getKey();
        _gameEntities[entityKey] = gameEntity;
        EntityState storage state = _entityStates[entityKey];
        if (state.isActive) revert EntityAlreadyInWorld();

        // Set entity state
        state.isActive = true;
        _worldEntities.add(uint256(entityKey));

        // Request spawning through EntityWorldReducer
        ENTITY_WORLD_REDUCER.spawnEntity(gameEntity, WORLD_ID);

        emit EntitySpawned(gameEntity, WORLD_ID, SINGLE_TILE);
    }

    function despawnEntity(GameEntity calldata gameEntity) external restricted {
        bytes32 entityKey = gameEntity.getKey();
        EntityState storage state = _entityStates[entityKey];
        if (!state.isActive) revert EntityNotInWorld();
        if (ENTITY_WORLD_DATASTORE.getEntityWorldId(gameEntity) != WORLD_ID)
            revert EntityNotInWorld();

        // Remove from world entities
        _worldEntities.remove(uint256(entityKey));

        // Update world through reducer
        ENTITY_WORLD_REDUCER.moveEntityBetweenWorlds(gameEntity, 0);

        // Clear entity state
        _clearEntityState(entityKey);

        emit EntityDespawned(gameEntity, WORLD_ID, SINGLE_TILE);
    }

    function _clearEntityState(bytes32 entityKey) private {
        delete _entityStates[entityKey].isActive;

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
            SINGLE_TILE,
            ENTITY_WORLD_DATASTORE.getEntityWorldId(gameEntity),
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
        // All portals in this world are at the single tile
        if (tile.packed != SINGLE_TILE.packed) return (false, 0);

        // Return the first portal if any exist
        if (_activePortalIds.length() > 0) {
            return (true, _activePortalIds.at(0));
        }

        return (false, 0);
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
        // Single tile world has no neighbors
        return new PackedTileCoordinate[](0);
    }

    function getEntitiesInTile(
        PackedTileCoordinate calldata tile,
        uint256 startIndex,
        uint256 count
    ) external view returns (GameEntity[] memory entities) {
        // Only return entities if the specified tile is the single tile
        if (tile.packed != SINGLE_TILE.packed) {
            return new GameEntity[](0);
        }

        uint256 totalEntities = _worldEntities.length();
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
            bytes32 entityKey = bytes32(_worldEntities.at(startIndex + i));
            entities[i] = _gameEntities[entityKey];
        }

        return entities;
    }

    function isEntityInTile(
        GameEntity calldata gameEntity,
        PackedTileCoordinate calldata tile
    ) external view returns (bool) {
        // Entity can only be in the single tile
        if (tile.packed != SINGLE_TILE.packed) return false;

        EntityState storage state = _entityStates[gameEntity.getKey()];
        return
            state.isActive &&
            ENTITY_WORLD_DATASTORE.getEntityWorldId(gameEntity) == WORLD_ID;
    }

    function areEntitiesInSameTile(
        GameEntity calldata gameEntity1,
        GameEntity calldata gameEntity2
    ) external view returns (bool) {
        // All entities in this world are in the same tile
        EntityState storage state1 = _entityStates[gameEntity1.getKey()];
        EntityState storage state2 = _entityStates[gameEntity2.getKey()];

        return
            state1.isActive &&
            state2.isActive &&
            ENTITY_WORLD_DATASTORE.getEntityWorldId(gameEntity1) == WORLD_ID &&
            ENTITY_WORLD_DATASTORE.getEntityWorldId(gameEntity2) == WORLD_ID;
    }

    function getEntityTile(
        GameEntity calldata gameEntity
    ) external view returns (PackedTileCoordinate memory) {
        EntityState storage state = _entityStates[gameEntity.getKey()];
        if (!state.isActive) revert EntityNotInWorld();
        // Always return the single tile
        return SINGLE_TILE;
    }

    function getEntityWorldId(
        GameEntity calldata gameEntity
    ) external view returns (uint256) {
        EntityState storage state = _entityStates[gameEntity.getKey()];
        if (!state.isActive) revert EntityNotInWorld();
        return ENTITY_WORLD_DATASTORE.getEntityWorldId(gameEntity);
    }
}
