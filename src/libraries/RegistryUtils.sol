// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library RegistryUtils {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    error AlreadyRegistered();
    error NotRegistered();
    error InvalidWorld();
    error Unauthorized();
    error EntityAlreadyInWorld();
    error EntityNotInWorld();
}
