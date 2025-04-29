// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IEntityNFT} from "../interfaces/IEntityNFT.sol";
import {GameEntity} from "../structs/GameEntity.sol";
import {GameEntityUtils} from "./GameEntityUtils.sol";

library RegistryUtils {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    error AlreadyRegistered();
    error NotRegistered();
    error InvalidWorld();
    error Unauthorized();
    error EntityAlreadyInWorld();
    error EntityNotInWorld();

    function addToSet(
        mapping(bytes32 => EnumerableSet.Bytes32Set) storage map,
        GameEntity memory entity,
        bytes32 value
    ) internal returns (bool) {
        bytes32 entityKey = GameEntityUtils.getKey(entity);
        if (map[entityKey].contains(value)) {
            return false;
        }
        map[entityKey].add(value);
        return true;
    }

    function removeFromSet(
        mapping(bytes32 => EnumerableSet.Bytes32Set) storage map,
        GameEntity memory entity,
        bytes32 value
    ) internal returns (bool) {
        bytes32 entityKey = GameEntityUtils.getKey(entity);
        if (!map[entityKey].contains(value)) {
            return false;
        }
        map[entityKey].remove(value);
        return true;
    }

    function isInSet(
        mapping(bytes32 => EnumerableSet.Bytes32Set) storage map,
        GameEntity memory entity,
        bytes32 value
    ) internal view returns (bool) {
        bytes32 entityKey = GameEntityUtils.getKey(entity);
        return map[entityKey].contains(value);
    }

    function addToSet(
        mapping(IEntityNFT => EnumerableSet.Bytes32Set) storage map,
        IEntityNFT entityNFT,
        bytes32 value
    ) internal returns (bool) {
        if (map[entityNFT].contains(value)) {
            return false;
        }
        map[entityNFT].add(value);
        return true;
    }

    function removeFromSet(
        mapping(IEntityNFT => EnumerableSet.Bytes32Set) storage map,
        IEntityNFT entityNFT,
        bytes32 value
    ) internal returns (bool) {
        if (!map[entityNFT].contains(value)) {
            return false;
        }
        map[entityNFT].remove(value);
        return true;
    }

    function isInSet(
        mapping(IEntityNFT => EnumerableSet.Bytes32Set) storage map,
        IEntityNFT entityNFT,
        bytes32 value
    ) internal view returns (bool) {
        return map[entityNFT].contains(value);
    }
}
