// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {IGameWorld} from "../interfaces/IGameWorld.sol";

/**
 * @title CoordinatePacking
 * @dev Library for packing and unpacking coordinates in a game world
 */
library CoordinatePacking {
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
    ) internal pure returns (IGameWorld.PackedTileCoordinate memory) {
        uint256 packed = (uint256(uint64(x)) << 192) |
            (uint256(uint64(y)) << 128) |
            uint256(uint128(z));
        return IGameWorld.PackedTileCoordinate(packed);
    }

    /**
     * @dev Unpacks a packed coordinate into x, y, z components
     * @param packed The packed coordinate
     * @return x The x coordinate
     * @return y The y coordinate
     * @return z The z coordinate
     */
    function unpackCoordinate(
        IGameWorld.PackedTileCoordinate memory packed
    ) internal pure returns (int64 x, int64 y, int128 z) {
        x = int64(uint64(packed.packed >> 192));
        y = int64(uint64(packed.packed >> 128));
        z = int128(uint128(packed.packed));
    }

    /**
     * @dev Packs x, y coordinates into a single uint256 (z is set to 0)
     * @param x The x coordinate (64 bits)
     * @param y The y coordinate (64 bits)
     * @return PackedTileCoordinate The packed coordinate
     */
    function packSquareCoordinate(
        int64 x,
        int64 y
    ) internal pure returns (IGameWorld.PackedTileCoordinate memory) {
        return packCoordinate(x, y, 0);
    }

    /**
     * @dev Unpacks a packed coordinate into x, y components (z is ignored)
     * @param packed The packed coordinate
     * @return x The x coordinate
     * @return y The y coordinate
     */
    function unpackSquareCoordinate(
        IGameWorld.PackedTileCoordinate memory packed
    ) internal pure returns (int64 x, int64 y) {
        (x, y, ) = unpackCoordinate(packed);
    }

    function getKey(
        IGameWorld.PackedTileCoordinate memory coord
    ) internal pure returns (bytes32) {
        return bytes32(coord.packed);
    }
}
