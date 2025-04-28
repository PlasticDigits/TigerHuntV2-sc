// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {GameEntity} from "../structs/GameEntity.sol";

library GameEntityUtils {
    function getKey(
        GameEntity memory gameEntity
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(gameEntity.entityNFT, gameEntity.entityId));
    }
}
