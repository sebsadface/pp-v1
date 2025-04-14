// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ModuleRegistry } from "@storyprotocol/core/registries/ModuleRegistry.sol";
import { ProtocolAdmin } from "@storyprotocol/core/lib/ProtocolAdmin.sol";

import { IRegistrationWorkflows } from "../../contracts/interfaces/workflows/IRegistrationWorkflows.sol";
import { ITokenizerModule } from "../../contracts/interfaces/modules/tokenizer/ITokenizerModule.sol";
import { StoryProtocolCoreAddressManager } from "../utils/StoryProtocolCoreAddressManager.sol";
import { StoryProtocolPeripheryAddressManager } from "../utils/StoryProtocolPeripheryAddressManager.sol";


/// @dev To use:
/// 1. have ADMIN_PRIVATE_KEY in .env
/// 2. have protocol addresses in deploy-out/deployment-<CHAIN_ID>.json
/// 3. run
/// `forge script script/upgradeSetup/UpgradeSetup.s.sol:UpgradeSetup --rpc-url=$STORY_RPC --broadcast --priority-gas-price=1 --legacy -vvvv`
contract UpgradeSetup is Script, StoryProtocolCoreAddressManager, StoryProtocolPeripheryAddressManager {
    enum Mode {
        SCHEDULE,
        EXECUTE
    }

    bytes[] internal calls;

    /// @notice The mode of the script.
    /// @notice on testnet and mainnet, we can directly execute the calls
    Mode public mode = Mode.EXECUTE;

    function run() public {
        _readStoryProtocolCoreAddresses();
        _readStoryProtocolPeripheryAddresses();

        vm.startBroadcast(vm.envUint("ADMIN_PRIVATE_KEY"));

        if (mode == Mode.SCHEDULE) {
            _prepareScheduleCalls();
            AccessManager(protocolAccessManagerAddr).multicall(calls);
        } else {
            _prepareExecuteCalls();
            if (block.chainid == 1514) {
                // the ownership of OwnableERC20Beacon is already transferred to TokenizerModule on testnet
                UpgradeableBeacon(ownableERC20BeaconAddr).transferOwnership(tokenizerModuleAddr);
            }
            AccessManager(protocolAccessManagerAddr).multicall(calls);
            _assertRoles();
        }

        vm.stopBroadcast();
    }

    function _prepareScheduleCalls() internal {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = UUPSUpgradeable.upgradeToAndCall.selector;

        // DerivativeWorkflows
        calls.push(
            _getScheduleCalldata(
                protocolAccessManagerAddr,
                abi.encodeCall(
                    AccessManager.setTargetFunctionRole,
                    (
                        derivativeWorkflowsAddr,
                        selectors,
                        ProtocolAdmin.UPGRADER_ROLE
                    )
                )
            )
        );

        // GroupingWorkflows
        calls.push(
            _getScheduleCalldata(
                protocolAccessManagerAddr,
                abi.encodeCall(
                    AccessManager.setTargetFunctionRole,
                    (
                        groupingWorkflowsAddr,
                        selectors,
                        ProtocolAdmin.UPGRADER_ROLE
                    )
                )
            )
        );

        // LicenseAttachmentWorkflows
        calls.push(
            _getScheduleCalldata(
                protocolAccessManagerAddr,
                abi.encodeCall(
                    AccessManager.setTargetFunctionRole,
                    (
                        licenseAttachmentWorkflowsAddr,
                        selectors,
                        ProtocolAdmin.UPGRADER_ROLE
                    )
                )
            )
        );

        // RoyaltyTokenDistributionWorkflows
        calls.push(
            _getScheduleCalldata(
                protocolAccessManagerAddr,
                abi.encodeCall(
                    AccessManager.setTargetFunctionRole,
                    (
                        royaltyTokenDistributionWorkflowsAddr,
                        selectors,
                        ProtocolAdmin.UPGRADER_ROLE
                    )
                )
            )
        );

        // RoyaltyWorkflows
        calls.push(
            _getScheduleCalldata(
                protocolAccessManagerAddr,
                abi.encodeCall(
                    AccessManager.setTargetFunctionRole,
                    (
                        royaltyWorkflowsAddr,
                        selectors,
                        ProtocolAdmin.UPGRADER_ROLE
                    )
                )
            )
        );

        // TokenizerModule
        selectors = new bytes4[](1);
        selectors[0] = ITokenizerModule.upgradeWhitelistedTokenTemplate.selector;
        calls.push(
            _getScheduleCalldata(
                protocolAccessManagerAddr,
                abi.encodeCall(
                    AccessManager.setTargetFunctionRole,
                    (
                        tokenizerModuleAddr,
                        selectors,
                        ProtocolAdmin.UPGRADER_ROLE
                    )
                )
            )
        );

        // RegistrationWorkflows
        selectors = new bytes4[](2);
        selectors[0] = UUPSUpgradeable.upgradeToAndCall.selector;
        selectors[1] = IRegistrationWorkflows.upgradeCollections.selector;
        calls.push(
            _getScheduleCalldata(
                protocolAccessManagerAddr,
                abi.encodeCall(
                    AccessManager.setTargetFunctionRole,
                    (
                        registrationWorkflowsAddr,
                        selectors,
                        ProtocolAdmin.UPGRADER_ROLE
                    )
                )
            )
        );

        // Module Registry
        // Upgrading Licensing Hooks requires both removeModule and registerModule
        // selectors = new bytes4[](2);
        // selectors[0] = ModuleRegistry.removeModule.selector;
        // selectors[1] = bytes4(keccak256("registerModule(string,address)"));
        // calls.push(
        //     _getScheduleCalldata(
        //         protocolAccessManagerAddr,
        //         abi.encodeCall(
        //             AccessManager.setTargetFunctionRole,
        //             (
        //                 moduleRegistryAddr,
        //                 selectors,
        //                 ProtocolAdmin.UPGRADER_ROLE
        //             )
        //         )
        //     )
        // );
    }

    function _prepareExecuteCalls() internal {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = UUPSUpgradeable.upgradeToAndCall.selector;

        // DerivativeWorkflows
        calls.push(
            _getExecuteCalldata(
                protocolAccessManagerAddr,
                abi.encodeCall(
                    AccessManager.setTargetFunctionRole,
                    (
                        derivativeWorkflowsAddr,
                        selectors,
                        ProtocolAdmin.UPGRADER_ROLE
                    )
                )
            )
        );

        // GroupingWorkflows
        calls.push(
            _getExecuteCalldata(
                protocolAccessManagerAddr,
                abi.encodeCall(
                    AccessManager.setTargetFunctionRole,
                    (
                        groupingWorkflowsAddr,
                        selectors,
                        ProtocolAdmin.UPGRADER_ROLE
                    )
                )
            )
        );

        // LicenseAttachmentWorkflows
        calls.push(
            _getExecuteCalldata(
                protocolAccessManagerAddr,
                abi.encodeCall(
                    AccessManager.setTargetFunctionRole,
                    (
                        licenseAttachmentWorkflowsAddr,
                        selectors,
                        ProtocolAdmin.UPGRADER_ROLE
                    )
                )
            )
        );

        // RoyaltyTokenDistributionWorkflows
        calls.push(
            _getExecuteCalldata(
                protocolAccessManagerAddr,
                abi.encodeCall(
                    AccessManager.setTargetFunctionRole,
                    (
                        royaltyTokenDistributionWorkflowsAddr,
                        selectors,
                        ProtocolAdmin.UPGRADER_ROLE
                    )
                )
            )
        );

        // RoyaltyWorkflows
        calls.push(
            _getExecuteCalldata(
                protocolAccessManagerAddr,
                abi.encodeCall(
                    AccessManager.setTargetFunctionRole,
                    (
                        royaltyWorkflowsAddr,
                        selectors,
                        ProtocolAdmin.UPGRADER_ROLE
                    )
                )
            )
        );

        // TokenizerModule
        selectors = new bytes4[](2);
        selectors[0] = UUPSUpgradeable.upgradeToAndCall.selector;
        selectors[1] = ITokenizerModule.upgradeWhitelistedTokenTemplate.selector;
        calls.push(
            _getExecuteCalldata(
                protocolAccessManagerAddr,
                abi.encodeCall(
                    AccessManager.setTargetFunctionRole,
                    (
                        tokenizerModuleAddr,
                        selectors,
                        ProtocolAdmin.UPGRADER_ROLE
                    )
                )
            )
        );

        // RegistrationWorkflows
        selectors = new bytes4[](2);
        selectors[0] = UUPSUpgradeable.upgradeToAndCall.selector;
        selectors[1] = IRegistrationWorkflows.upgradeCollections.selector;
        calls.push(
            _getExecuteCalldata(
                protocolAccessManagerAddr,
                abi.encodeCall(
                    AccessManager.setTargetFunctionRole,
                    (
                        registrationWorkflowsAddr,
                        selectors,
                        ProtocolAdmin.UPGRADER_ROLE
                    )
                )
            )
        );

        // Module Registry
        // Upgrading Licensing Hooks requires both removeModule and registerModule
        // selectors = new bytes4[](2);
        // selectors[0] = ModuleRegistry.removeModule.selector;
        // selectors[1] = bytes4(keccak256("registerModule(string,address)"));
        // calls.push(
        //     _getExecuteCalldata(
        //         protocolAccessManagerAddr,
        //         abi.encodeCall(
        //             AccessManager.setTargetFunctionRole,
        //             (
        //                 moduleRegistryAddr,
        //                 selectors,
        //                 ProtocolAdmin.UPGRADER_ROLE
        //             )
        //         )
        //     )
        // );
    }

    function _getScheduleCalldata(address target, bytes memory data) internal returns (bytes memory) {
        return abi.encodeCall(
            AccessManager.schedule,
            (
                target,
                data,
                0
            )
        );
    }

    function _getExecuteCalldata(address target, bytes memory data) internal returns (bytes memory) {
        return abi.encodeCall(
            AccessManager.execute,
            (
                target,
                data
            )
        );
    }

    function _assertRoles() internal {
        // Check that all the target function roles are properly set
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = UUPSUpgradeable.upgradeToAndCall.selector;

        // Verify workflow contracts have UPGRADER_ROLE set for upgradeToAndCall
        require(
            AccessManager(protocolAccessManagerAddr).getTargetFunctionRole(
                derivativeWorkflowsAddr,
                selectors[0]
            ) == ProtocolAdmin.UPGRADER_ROLE,
            "DerivativeWorkflows: UPGRADER_ROLE not set"
        );

        require(
            AccessManager(protocolAccessManagerAddr).getTargetFunctionRole(
                groupingWorkflowsAddr,
                selectors[0]
            ) == ProtocolAdmin.UPGRADER_ROLE,
            "GroupingWorkflows: UPGRADER_ROLE not set"
        );

        require(
            AccessManager(protocolAccessManagerAddr).getTargetFunctionRole(
                licenseAttachmentWorkflowsAddr,
                selectors[0]
            ) == ProtocolAdmin.UPGRADER_ROLE,
            "LicenseAttachmentWorkflows: UPGRADER_ROLE not set"
        );

        require(
            AccessManager(protocolAccessManagerAddr).getTargetFunctionRole(
                royaltyTokenDistributionWorkflowsAddr,
                selectors[0]
            ) == ProtocolAdmin.UPGRADER_ROLE,
            "RoyaltyTokenDistributionWorkflows: UPGRADER_ROLE not set"
        );

        require(
            AccessManager(protocolAccessManagerAddr).getTargetFunctionRole(
                royaltyWorkflowsAddr,
                selectors[0]
            ) == ProtocolAdmin.UPGRADER_ROLE,
            "RoyaltyWorkflows: UPGRADER_ROLE not set"
        );

        require(
            AccessManager(protocolAccessManagerAddr).getTargetFunctionRole(
                registrationWorkflowsAddr,
                selectors[0]
            ) == ProtocolAdmin.UPGRADER_ROLE,
            "RegistrationWorkflows: UPGRADER_ROLE not set"
        );

        // Check ITokenizerModule.upgradeWhitelistedTokenTemplate role
        bytes4[] memory tokenizerSelectors = new bytes4[](2);
        tokenizerSelectors[0] = UUPSUpgradeable.upgradeToAndCall.selector;
        tokenizerSelectors[1] = ITokenizerModule.upgradeWhitelistedTokenTemplate.selector;
        require(
            AccessManager(protocolAccessManagerAddr).getTargetFunctionRole(
                tokenizerModuleAddr,
                tokenizerSelectors[0]
            ) == ProtocolAdmin.UPGRADER_ROLE,
            "TokenizerModule: UPGRADER_ROLE not set for upgradeWhitelistedTokenTemplate"
        );

        // Check IRegistrationWorkflows.upgradeCollections role
        bytes4[] memory registrationSelectors = new bytes4[](1);
        registrationSelectors[0] = IRegistrationWorkflows.upgradeCollections.selector;
        require(
            AccessManager(protocolAccessManagerAddr).getTargetFunctionRole(
                registrationWorkflowsAddr,
                registrationSelectors[0]
            ) == ProtocolAdmin.UPGRADER_ROLE,
            "RegistrationWorkflows: UPGRADER_ROLE not set for upgradeCollections"
        );

        // Verify ModuleRegistry has UPGRADER_ROLE set for removeModule and registerModule
        bytes4[] memory moduleSelectors = new bytes4[](2);
        moduleSelectors[0] = ModuleRegistry.removeModule.selector;
        moduleSelectors[1] = bytes4(keccak256("registerModule(string,address)"));

        require(
            AccessManager(protocolAccessManagerAddr).getTargetFunctionRole(
                moduleRegistryAddr,
                moduleSelectors[0]
            ) == ProtocolAdmin.PROTOCOL_ADMIN_ROLE,
            "ModuleRegistry: UPGRADER_ROLE not set for removeModule"
        );

        require(
            AccessManager(protocolAccessManagerAddr).getTargetFunctionRole(
                moduleRegistryAddr,
                moduleSelectors[1]
            ) == ProtocolAdmin.PROTOCOL_ADMIN_ROLE,
            "ModuleRegistry: UPGRADER_ROLE not set for registerModule"
        );

        // Check ownership transfer for OwnableERC20Beacon on Story Odyssey testnet
        require(
            Ownable(ownableERC20BeaconAddr).owner() == tokenizerModuleAddr,
            "OwnableERC20Beacon: ownership not transferred to TokenizerModule"
        );
    }

}
