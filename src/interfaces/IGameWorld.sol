// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {GameEntity} from "../structs/GameEntity.sol";

interface IGameWorld {
    // Struct to represent a packed tile coordinate
    // x: 64 bits, y: 64 bits, z: 128 bits
    struct PackedTileCoordinate {
        uint256 packed;
    }

    // Struct to represent a world portal
    struct WorldPortal {
        PackedTileCoordinate sourceTile;
        PackedTileCoordinate targetTile;
        uint256 targetWorldId;
    }

    // Events
    event EntityMoved(
        GameEntity indexed gameEntity,
        PackedTileCoordinate fromTile,
        PackedTileCoordinate toTile
    );
    event EntityEnteredWorld(
        GameEntity indexed gameEntity,
        uint256 worldId,
        PackedTileCoordinate tile
    );
    event EntityExitedWorld(
        GameEntity indexed gameEntity,
        uint256 worldId,
        PackedTileCoordinate tile
    );
    event EntitySpawned(
        GameEntity indexed gameEntity,
        uint256 worldId,
        PackedTileCoordinate tile
    );
    event EntityDespawned(
        GameEntity indexed gameEntity,
        uint256 worldId,
        PackedTileCoordinate tile
    );
    event PortalCreated(
        uint256 indexed portalId,
        uint256 indexed worldId,
        PackedTileCoordinate sourceTile,
        PackedTileCoordinate targetTile,
        uint256 targetWorldId
    );
    event PortalRemoved(uint256 indexed portalId, uint256 indexed worldId);

    // Errors
    error InvalidTileCoordinate();
    error EntityNotInTile();
    error TileOccupied();
    error InvalidWorldPortal();
    error WorldPortalNotAvailable();
    error CoordinateOverflow();
    error PortalAlreadyExists();
    error PortalNotFound();
    error InvalidWorldId();
    error Unauthorized();
    error EntityAlreadyInWorld();
    error EntityNotInWorld();
    error InvalidPortalId();
    error WorldSizeExceeded();

    /**
     * @dev Packs x, y, z coordinates into a single uint256
     * @param x The x coordinate (64 bits)
     * @param y The y coordinate (64 bits)
     * @param z The z coordinate (128 bits)
     * @return PackedTileCoordinate The packed coordinate
     */
    function packCoordinate(
        int64 x,
        int64 y,
        int128 z
    ) external pure returns (PackedTileCoordinate memory);

    /**
     * @dev Unpacks a packed coordinate into x, y, z components
     * @param packed The packed coordinate
     * @return x The x coordinate
     * @return y The y coordinate
     * @return z The z coordinate
     */
    function unpackCoordinate(
        PackedTileCoordinate calldata packed
    ) external pure returns (int64 x, int64 y, int128 z);

    /**
     * @dev Returns the neighboring tiles of a given tile
     * @param tile The packed tile coordinate to get neighbors for
     * @return PackedTileCoordinate[] Array of neighboring packed tile coordinates
     */
    function getNeighboringTiles(
        PackedTileCoordinate calldata tile
    ) external view returns (PackedTileCoordinate[] memory);

    /**
     * @dev Returns a paginated list of entities in a given tile
     * @param tile The packed tile coordinate to get entities for
     * @param startIndex The starting index for pagination
     * @param count The number of entities to return
     * @return GameEntity[] Array of entity references in the tile
     */
    function getEntitiesInTile(
        PackedTileCoordinate calldata tile,
        uint256 startIndex,
        uint256 count
    ) external view returns (GameEntity[] memory);

    /**
     * @dev Checks if an entity is in a given tile
     * @param gameEntity The entity reference to check
     * @param tile The packed tile coordinate to check
     * @return bool True if the entity is in the tile
     */
    function isEntityInTile(
        GameEntity calldata gameEntity,
        PackedTileCoordinate calldata tile
    ) external view returns (bool);

    /**
     * @dev Checks if two entities are in the same tile
     * @param gameEntity1 The first entity reference
     * @param gameEntity2 The second entity reference
     * @return bool True if both entities are in the same tile
     */
    function areEntitiesInSameTile(
        GameEntity calldata gameEntity1,
        GameEntity calldata gameEntity2
    ) external view returns (bool);

    /**
     * @dev Moves an entity to a new tile
     * @param gameEntity The entity reference to move
     * @param fromTile The current packed tile coordinate
     * @param toTile The target packed tile coordinate
     */
    function moveEntity(
        GameEntity calldata gameEntity,
        PackedTileCoordinate calldata fromTile,
        PackedTileCoordinate calldata toTile
    ) external;

    /**
     * @dev Transfers an entity to another world through a portal
     * @param gameEntity The entity reference to transfer
     * @param portal The world portal to use
     */
    function transferEntityThroughPortal(
        GameEntity calldata gameEntity,
        WorldPortal calldata portal
    ) external;

    /**
     * @dev Gets the current tile of an entity
     * @param gameEntity The entity reference to check
     * @return PackedTileCoordinate The current packed tile coordinate of the entity
     */
    function getEntityTile(
        GameEntity calldata gameEntity
    ) external view returns (PackedTileCoordinate memory);

    /**
     * @dev Gets the current world ID of an entity
     * @param gameEntity The entity reference to check
     * @return uint256 The current world ID of the entity
     */
    function getEntityWorldId(
        GameEntity calldata gameEntity
    ) external view returns (uint256);

    /**
     * @dev Creates a new world portal
     * @param worldId The ID of the world where the portal is created
     * @param sourceTile The source tile coordinate
     * @param targetTile The target tile coordinate
     * @param targetWorldId The ID of the target world
     * @return portalId The ID of the newly created portal
     */
    function createPortal(
        uint256 worldId,
        PackedTileCoordinate calldata sourceTile,
        PackedTileCoordinate calldata targetTile,
        uint256 targetWorldId
    ) external returns (uint256 portalId);

    /**
     * @dev Removes an existing world portal
     * @param portalId The ID of the portal to remove
     * @param worldId The ID of the world containing the portal
     */
    function removePortal(uint256 portalId, uint256 worldId) external;

    /**
     * @dev Gets the details of a specific portal
     * @param portalId The ID of the portal
     * @param worldId The ID of the world containing the portal
     * @return WorldPortal The portal details
     */
    function getPortal(
        uint256 portalId,
        uint256 worldId
    ) external view returns (WorldPortal memory);

    /**
     * @dev Gets all portals in a world
     * @param worldId The ID of the world
     * @param startIndex The starting index for pagination
     * @param count The number of portals to return
     * @return portalIds Array of portal IDs
     * @return portals Array of portal details
     */
    function getPortalsInWorld(
        uint256 worldId,
        uint256 startIndex,
        uint256 count
    )
        external
        view
        returns (uint256[] memory portalIds, WorldPortal[] memory portals);

    /**
     * @dev Checks if a portal exists at a given tile
     * @param worldId The ID of the world
     * @param tile The tile coordinate to check
     * @return bool True if a portal exists at the tile
     * @return uint256 The ID of the portal if it exists
     */
    function isPortalAtTile(
        uint256 worldId,
        PackedTileCoordinate calldata tile
    ) external view returns (bool, uint256);

    /**
     * @dev Gets the state of an entity
     * @param gameEntity The entity reference to get the state for
     * @return tile The packed tile coordinate of the entity
     * @return worldId The ID of the world the entity is in
     * @return isActive Whether the entity is active
     */
    function getEntityState(
        GameEntity calldata gameEntity
    )
        external
        view
        returns (
            PackedTileCoordinate memory tile,
            uint256 worldId,
            bool isActive
        );

    /**
     * @dev Spawns a new entity in the world at the specified tile
     * @param gameEntity The entity reference to spawn
     * @param tile The tile coordinate to spawn at
     */
    function spawnEntity(
        GameEntity calldata gameEntity,
        PackedTileCoordinate calldata tile
    ) external;

    /**
     * @dev Despawns an entity from the world
     * @param gameEntity The entity reference to despawn
     */
    function despawnEntity(GameEntity calldata gameEntity) external;
}
