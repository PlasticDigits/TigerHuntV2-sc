// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {ActionRegistry} from "../src/registries/ActionRegistry.sol";
import {Action} from "../src/structs/Action.sol";
import {MockEntityNFT} from "./mocks/MockEntityNFT.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract ActionRegistryTest is Test {
    ActionRegistry public actionRegistry;
    MockEntityNFT public entity1;
    MockEntityNFT public entity2;
    address public actionManager;
    address public nonManager;
    uint256 public constant TOKEN_ID_1 = 1;
    uint256 public constant TOKEN_ID_2 = 2;

    function setUp() public {
        actionRegistry = new ActionRegistry();
        actionManager = makeAddr("actionManager");
        nonManager = makeAddr("nonManager");

        // Create entities
        entity1 = new MockEntityNFT();
        entity2 = new MockEntityNFT();

        // Mint tokens to test users
        entity1.mint(actionManager, TOKEN_ID_1);
        entity2.mint(actionManager, TOKEN_ID_2);

        // Grant ACTION_MANAGER_ROLE to actionManager
        vm.prank(
            actionRegistry.getRoleMember(actionRegistry.DEFAULT_ADMIN_ROLE(), 0)
        );
        actionRegistry.grantRole(
            actionRegistry.ACTION_MANAGER_ROLE(),
            actionManager
        );
    }

    // Helper function to create a unique action based on an index
    function createUniqueAction(
        uint256 index
    ) internal view returns (Action memory) {
        // Use XOR to combine timestamp and index in a way that won't overflow
        uint256 combined = block.timestamp ^ index;
        return
            Action({
                target: address(uint160(combined)),
                selector: bytes4(bytes32(combined)),
                duration: uint64(combined % 1000)
            });
    }

    // Test basic action management
    function test_AllowAndDisallowAction() public {
        Action memory action = createUniqueAction(0);

        // Allow action
        vm.prank(actionManager);
        actionRegistry.allowAction(entity1, action);

        // Verify action is allowed
        assertTrue(actionRegistry.isActionAllowed(entity1, action));

        // Disallow action
        vm.prank(actionManager);
        actionRegistry.disallowAction(entity1, action);

        // Verify action is disallowed
        assertFalse(actionRegistry.isActionAllowed(entity1, action));
    }

    // Test permission checks
    function test_OnlyActionManagerCanManageActions() public {
        Action memory action = createUniqueAction(0);

        // Make sure nonManager does not have the role
        assertFalse(
            actionRegistry.hasRole(
                actionRegistry.ACTION_MANAGER_ROLE(),
                nonManager
            )
        );

        // Non-manager tries to allow action
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonManager,
                actionRegistry.ACTION_MANAGER_ROLE()
            )
        );
        vm.prank(nonManager);
        actionRegistry.allowAction(entity1, action);

        // Manager allows action
        vm.prank(actionManager);
        actionRegistry.allowAction(entity1, action);

        // Non-manager tries to disallow action
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonManager,
                actionRegistry.ACTION_MANAGER_ROLE()
            )
        );
        vm.prank(nonManager);
        actionRegistry.disallowAction(entity1, action);
    }

    // Test duplicate actions
    function test_DuplicateActions() public {
        Action memory action = createUniqueAction(0);

        // Allow action
        vm.prank(actionManager);
        actionRegistry.allowAction(entity1, action);

        // Try to allow same action again
        vm.prank(actionManager);
        vm.expectRevert(abi.encodeWithSignature("AlreadyRegistered()"));
        actionRegistry.allowAction(entity1, action);
    }

    // Test disallowing non-existent action
    function test_DisallowNonExistentAction() public {
        Action memory action = createUniqueAction(0);

        vm.prank(actionManager);
        vm.expectRevert(abi.encodeWithSignature("NotRegistered()"));
        actionRegistry.disallowAction(entity1, action);
    }

    // Fuzzing test for multiple actions
    function testFuzz_MultipleActions(uint256 seed) public {
        // Limit the number of actions to prevent stack too deep
        uint256 numActions = 5;
        Action[] memory actions = new Action[](numActions);

        // Create unique actions using the seed
        for (uint256 i = 0; i < numActions; i++) {
            // Use XOR to combine seed and i in a way that won't overflow
            actions[i] = createUniqueAction(seed ^ i);
        }

        // Allow all actions
        vm.startPrank(actionManager);
        for (uint256 i = 0; i < numActions; i++) {
            actionRegistry.allowAction(entity1, actions[i]);
            assertTrue(actionRegistry.isActionAllowed(entity1, actions[i]));
        }
        vm.stopPrank();

        // Verify all actions are allowed
        for (uint256 i = 0; i < numActions; i++) {
            assertTrue(actionRegistry.isActionAllowed(entity1, actions[i]));
        }

        // Disallow all actions
        vm.startPrank(actionManager);
        for (uint256 i = 0; i < numActions; i++) {
            actionRegistry.disallowAction(entity1, actions[i]);
            assertFalse(actionRegistry.isActionAllowed(entity1, actions[i]));
        }
        vm.stopPrank();
    }

    // Differential test between entities
    function test_DifferentialBetweenEntities() public {
        Action memory action = createUniqueAction(0);

        // Allow action for entity1
        vm.prank(actionManager);
        actionRegistry.allowAction(entity1, action);

        // Verify action is allowed for entity1 but not entity2
        assertTrue(actionRegistry.isActionAllowed(entity1, action));
        assertFalse(actionRegistry.isActionAllowed(entity2, action));

        // Allow action for entity2
        vm.prank(actionManager);
        actionRegistry.allowAction(entity2, action);

        // Verify action is allowed for both entities
        assertTrue(actionRegistry.isActionAllowed(entity1, action));
        assertTrue(actionRegistry.isActionAllowed(entity2, action));
    }

    // Invariant test for action uniqueness
    function test_Invariant_ActionUniqueness() public {
        Action memory action = createUniqueAction(0);

        // Allow action
        vm.prank(actionManager);
        actionRegistry.allowAction(entity1, action);

        // Create a new action with same target and selector but different duration
        Action memory similarAction = Action({
            target: action.target,
            selector: action.selector,
            duration: action.duration + 1
        });

        // Try to allow similar action
        vm.prank(actionManager);
        vm.expectRevert(abi.encodeWithSignature("AlreadyRegistered()"));
        actionRegistry.allowAction(entity1, similarAction);
    }

    // Test event emissions
    function test_EventEmissions() public {
        Action memory action = createUniqueAction(0);

        // Test ActionAllowed event
        vm.expectEmit(true, true, true, true);
        emit ActionRegistry.ActionAllowed(
            entity1,
            action.selector,
            action.target
        );
        vm.prank(actionManager);
        actionRegistry.allowAction(entity1, action);

        // Test ActionDisallowed event
        vm.expectEmit(true, true, true, true);
        emit ActionRegistry.ActionDisallowed(
            entity1,
            action.selector,
            action.target
        );
        vm.prank(actionManager);
        actionRegistry.disallowAction(entity1, action);
    }

    // Test getAllowedActions
    function test_GetAllowedActions() public {
        uint256 numActions = 3;
        Action[] memory actions = new Action[](numActions);

        // Create unique actions
        for (uint256 i = 0; i < numActions; i++) {
            actions[i] = createUniqueAction(i);
        }

        // Allow all actions
        vm.startPrank(actionManager);
        for (uint256 i = 0; i < numActions; i++) {
            actionRegistry.allowAction(entity1, actions[i]);
        }
        vm.stopPrank();

        // Get all allowed actions
        bytes32[] memory allowedActions = actionRegistry.getAllowedActions(
            entity1
        );

        // Verify number of allowed actions
        assertEq(allowedActions.length, numActions);

        // Verify each action is in the allowed actions list
        for (uint256 i = 0; i < numActions; i++) {
            bytes32 actionKey = keccak256(
                abi.encode(actions[i].target, actions[i].selector)
            );
            bool found = false;
            for (uint256 j = 0; j < allowedActions.length; j++) {
                if (allowedActions[j] == actionKey) {
                    found = true;
                    break;
                }
            }
            assertTrue(found, "Action not found in allowed actions list");
        }
    }

    // Test edge cases for action parameters
    function test_ActionParameterEdgeCases() public {
        // Test zero duration
        Action memory zeroDurationAction = Action({
            target: address(uint160(1)),
            selector: bytes4(bytes32(uint256(1))),
            duration: 0
        });

        vm.prank(actionManager);
        actionRegistry.allowAction(entity1, zeroDurationAction);
        assertTrue(actionRegistry.isActionAllowed(entity1, zeroDurationAction));

        // Test maximum duration
        Action memory maxDurationAction = Action({
            target: address(uint160(2)),
            selector: bytes4(bytes32(uint256(2))),
            duration: type(uint64).max
        });

        vm.prank(actionManager);
        actionRegistry.allowAction(entity1, maxDurationAction);
        assertTrue(actionRegistry.isActionAllowed(entity1, maxDurationAction));

        // Test zero address target
        Action memory zeroAddressAction = Action({
            target: address(0),
            selector: bytes4(bytes32(uint256(3))),
            duration: 100
        });

        vm.prank(actionManager);
        actionRegistry.allowAction(entity1, zeroAddressAction);
        assertTrue(actionRegistry.isActionAllowed(entity1, zeroAddressAction));
    }

    // Test batch operations
    function test_BatchOperations() public {
        uint256 numActions = 3;
        Action[] memory actions = new Action[](numActions);

        // Create unique actions
        for (uint256 i = 0; i < numActions; i++) {
            actions[i] = createUniqueAction(i);
        }

        // Allow all actions in a single transaction
        vm.startPrank(actionManager);
        for (uint256 i = 0; i < numActions; i++) {
            actionRegistry.allowAction(entity1, actions[i]);
        }
        vm.stopPrank();

        // Verify all actions are allowed
        for (uint256 i = 0; i < numActions; i++) {
            assertTrue(actionRegistry.isActionAllowed(entity1, actions[i]));
        }

        // Disallow all actions in a single transaction
        vm.startPrank(actionManager);
        for (uint256 i = 0; i < numActions; i++) {
            actionRegistry.disallowAction(entity1, actions[i]);
        }
        vm.stopPrank();

        // Verify all actions are disallowed
        for (uint256 i = 0; i < numActions; i++) {
            assertFalse(actionRegistry.isActionAllowed(entity1, actions[i]));
        }
    }

    // Test gas usage with large number of actions
    function test_GasUsage() public {
        uint256 numActions = 50;
        Action[] memory actions = new Action[](numActions);
        uint256 startGas;

        // Create unique actions
        for (uint256 i = 0; i < numActions; i++) {
            actions[i] = createUniqueAction(i);
        }

        // Measure gas for allowing actions
        vm.startPrank(actionManager);
        startGas = gasleft();
        for (uint256 i = 0; i < numActions; i++) {
            actionRegistry.allowAction(entity1, actions[i]);
        }
        uint256 allowGasUsed = startGas - gasleft();

        // Measure gas for disallowing actions
        startGas = gasleft();
        for (uint256 i = 0; i < numActions; i++) {
            actionRegistry.disallowAction(entity1, actions[i]);
        }
        uint256 disallowGasUsed = startGas - gasleft();

        // Log gas usage for analysis
        console2.log("Gas used for allowing actions:", allowGasUsed);
        console2.log("Gas used for disallowing actions:", disallowGasUsed);
        vm.stopPrank();
    }
}
