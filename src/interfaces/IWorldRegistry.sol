// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {IGameWorld} from "./IGameWorld.sol";

interface IWorldRegistry {
    event WorldUnregistered(uint256 worldId, IGameWorld world);
    event WorldRegistered(uint256 worldId, IGameWorld world);

    error AlreadyRegistered();
    error NotRegistered();

    function registerWorld(IGameWorld world) external;
    function unregisterWorld(IGameWorld world) external;
    function isWorldRegistered(IGameWorld world) external view returns (bool);
    function getWorldId(IGameWorld world) external view returns (uint256);
    function getWorldFromWorldId(
        uint256 worldId
    ) external view returns (IGameWorld);
}
