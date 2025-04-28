// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {IGameWorld} from "../../src/interfaces/IGameWorld.sol";
import {IEntityNFT} from "../../src/interfaces/IEntityNFT.sol";
import {GameEntity} from "../../src/structs/GameEntity.sol";

contract MockGameWorld is IGameWorld {
    // Simple implementation that just returns true for all checks
    // This is sufficient for testing the WorldRegistry

    function moveEntity(
        GameEntity calldata gameEntity,
        PackedTileCoordinate calldata fromTile,
        PackedTileCoordinate calldata toTile
    ) external override {}

    function transferEntityThroughPortal(
        GameEntity calldata gameEntity,
        WorldPortal calldata portal
    ) external override {}

    function getEntityState(
        GameEntity calldata //gameEntity
    )
        external
        pure
        override
        returns (
            PackedTileCoordinate memory tile,
            uint256 worldId,
            bool isActive
        )
    {
        return (PackedTileCoordinate(0), 0, false);
    }

    function createPortal(
        uint256, // worldId,
        PackedTileCoordinate calldata, // sourceTile,
        PackedTileCoordinate calldata, // targetTile,
        uint256 // targetWorldId
    ) external pure override returns (uint256) {
        return 1;
    }

    function getPortal(
        uint256, // portalId,
        uint256 // worldId
    ) external pure override returns (WorldPortal memory) {
        return
            WorldPortal({
                sourceTile: PackedTileCoordinate(0),
                targetTile: PackedTileCoordinate(0),
                targetWorldId: 0
            });
    }

    function packCoordinate(
        int64, // x
        int64, // y
        int128 // z
    ) external pure override returns (PackedTileCoordinate memory) {
        return PackedTileCoordinate(0);
    }

    function unpackCoordinate(
        PackedTileCoordinate calldata // packed
    ) external pure override returns (int64 x, int64 y, int128 z) {
        return (0, 0, 0);
    }

    function getNeighboringTiles(
        PackedTileCoordinate calldata // tile
    ) external pure override returns (PackedTileCoordinate[] memory) {
        return new PackedTileCoordinate[](0);
    }

    function getEntitiesInTile(
        PackedTileCoordinate calldata, // tile
        uint256, // startIndex
        uint256 // count
    ) external pure override returns (GameEntity[] memory) {
        return new GameEntity[](0);
    }

    function isEntityInTile(
        GameEntity calldata, // gameEntity
        PackedTileCoordinate calldata // tile
    ) external pure override returns (bool) {
        return false;
    }

    function areEntitiesInSameTile(
        GameEntity calldata, // gameEntity1
        GameEntity calldata // gameEntity2
    ) external pure override returns (bool) {
        return false;
    }

    function getEntityTile(
        GameEntity calldata // gameEntity
    ) external pure override returns (PackedTileCoordinate memory) {
        return PackedTileCoordinate(0);
    }

    function getEntityWorldId(
        GameEntity calldata // gameEntity
    ) external pure override returns (uint256) {
        return 0;
    }

    function removePortal(
        uint256, // portalId,
        uint256 // worldId
    ) external override {}

    function getPortalsInWorld(
        uint256, // worldId,
        uint256, // startIndex,
        uint256 // count
    )
        external
        pure
        override
        returns (uint256[] memory portalIds, WorldPortal[] memory portals)
    {
        return (new uint256[](0), new WorldPortal[](0));
    }

    function isPortalAtTile(
        uint256, // worldId,
        PackedTileCoordinate calldata // tile
    ) external pure override returns (bool, uint256) {
        return (false, 0);
    }

    function spawnEntity(
        GameEntity calldata, // gameEntity
        PackedTileCoordinate calldata // tile
    ) external override {}

    function despawnEntity(
        GameEntity calldata // gameEntity
    ) external override {}
}
