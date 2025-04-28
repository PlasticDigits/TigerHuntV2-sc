// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {Action} from "../structs/Action.sol";
import {IEntityNFT} from "../interfaces/IEntityNFT.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {RegistryUtils} from "../libraries/RegistryUtils.sol";

contract ActionRegistry is AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using RegistryUtils for mapping(IEntityNFT entityNFT => EnumerableSet.Bytes32Set allowedActions);

    // Role for managing actions
    bytes32 public constant ACTION_MANAGER_ROLE =
        keccak256("ACTION_MANAGER_ROLE");

    // Mapping from entity NFT to allowed actions
    mapping(IEntityNFT entityNFT => EnumerableSet.Bytes32Set allowedActions)
        private _allowedActions;

    // Events
    event ActionAllowed(
        IEntityNFT indexed entityNFT,
        bytes4 selector,
        address target
    );
    event ActionDisallowed(
        IEntityNFT indexed entityNFT,
        bytes4 selector,
        address target
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ACTION_MANAGER_ROLE, msg.sender);
    }

    /**
     * @dev Allows an action to be performed on an entity
     * @param entityNFT The entity that will receive the action
     * @param action The action to allow
     */
    function allowAction(
        IEntityNFT entityNFT,
        Action calldata action
    ) external onlyRole(ACTION_MANAGER_ROLE) {
        bytes32 actionKey = keccak256(
            abi.encode(action.target, action.selector)
        );
        if (!_allowedActions.addToSet(entityNFT, actionKey)) {
            revert RegistryUtils.AlreadyRegistered();
        }

        emit ActionAllowed(entityNFT, action.selector, action.target);
    }

    /**
     * @dev Disallows an action from being performed on an entity
     * @param entityNFT The entity that will no longer receive the action
     * @param action The action to disallow
     */
    function disallowAction(
        IEntityNFT entityNFT,
        Action calldata action
    ) external onlyRole(ACTION_MANAGER_ROLE) {
        bytes32 actionKey = keccak256(
            abi.encode(action.target, action.selector)
        );
        if (!_allowedActions.removeFromSet(entityNFT, actionKey)) {
            revert RegistryUtils.NotRegistered();
        }

        emit ActionDisallowed(entityNFT, action.selector, action.target);
    }

    /**
     * @dev Checks if an action is allowed for an entity
     * @param entityNFT The entity to check
     * @param action The action to check
     * @return bool True if the action is allowed
     */
    function isActionAllowed(
        IEntityNFT entityNFT,
        Action calldata action
    ) external view returns (bool) {
        bytes32 actionKey = keccak256(
            abi.encode(action.target, action.selector)
        );
        return _allowedActions.isInSet(entityNFT, actionKey);
    }

    /**
     * @dev Gets all allowed actions for an entity
     * @param entityNFT The entity to get actions for
     * @return bytes32[] Array of action keys
     */
    function getAllowedActions(
        IEntityNFT entityNFT
    ) external view returns (bytes32[] memory) {
        return _allowedActions[entityNFT].values();
    }
}
