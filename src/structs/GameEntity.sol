// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {IEntityNFT} from "../interfaces/IEntityNFT.sol";

/**
 * @dev Struct to represent a game entity
 * @param entityNFT The NFT contract that owns this entity
 * @param entityId The ID of the entity
 */
struct GameEntity {
    IEntityNFT entityNFT;
    uint256 entityId;
}
