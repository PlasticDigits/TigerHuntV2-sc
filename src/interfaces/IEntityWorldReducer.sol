// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {GameEntity} from "../structs/GameEntity.sol";
import {IGameWorld} from "./IGameWorld.sol";

interface IEntityWorldReducer {
    error EntityNotInWorld();
    error EntityAlreadyInWorld();
    error Unauthorized();
    error InvalidWorld();

    function moveEntityBetweenWorlds(
        GameEntity calldata gameEntity,
        uint256 targetWorldId
    ) external;

    function spawnEntity(
        GameEntity calldata gameEntity,
        uint256 targetWorldId
    ) external;
}
