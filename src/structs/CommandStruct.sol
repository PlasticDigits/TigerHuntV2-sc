// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {ICommandImplementer} from "../interfaces/ICommandImplementer.sol";

struct CommandStruct {
    string ipfsMetadataHash; // IPFS hash of the command metadata (includes schema, name, description, image, etc.)
    bytes32 commandId; // Unique identifier (e.g., keccak256("EAT"))
    bytes32 allowedCommandsKey; // Key for allowed commands, 0x0 if any
    uint64 cooldown; // Time before action can be repeated
    uint64 duration; // How long the action takes
    ICommandImplementer implementer; // Contract that implements the command
}
