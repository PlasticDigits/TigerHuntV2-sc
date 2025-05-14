// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {GameEntity} from "../structs/GameEntity.sol";

type CommandsAllowedKey = bytes32;

interface ICommandImplementer {}

interface ICmdImplSelf is ICommandImplementer {
    function execute(
        bytes32 commandId,
        GameEntity calldata entity,
        bytes calldata commandData
    ) external returns (CommandsAllowedKey);
}

interface ICmdImplEntity is ICommandImplementer {
    function execute(
        bytes32 commandId,
        GameEntity calldata sourceEntity,
        GameEntity calldata targetEntity,
        bytes calldata commandData
    ) external returns (CommandsAllowedKey);
}

interface ICmdImplWorld is ICommandImplementer {
    function execute(
        bytes32 commandId,
        GameEntity calldata entity,
        bytes calldata commandData
    ) external returns (CommandsAllowedKey);
}
