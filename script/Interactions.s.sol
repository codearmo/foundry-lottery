// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function CreateSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();

        (
            ,
            ,
            address vrfCoordinatior,
            ,
            ,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinatior, deployerKey);
    }

    function createSubscription(
        address vrfCoordinatior,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creating subscription on Chainid", block.chainid);
        vm.startBroadcast(deployerKey);

        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinatior)
            .createSubscription();

        vm.stopBroadcast();
        console.log("You subscription id is  ", subId);
        console.log("Please update subsciprtion id in HelperConfig.sol");
        return subId;
    }

    function run() external returns (uint64) {
        return CreateSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();

        (
            ,
            ,
            address vrfCoordinatior,
            ,
            ,
            uint64 subId,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        fundSubscription(vrfCoordinatior, subId, link, deployerKey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address link,
        uint256 deployerKey
    ) public {
        console.log("Funding subscription on Chainid", subId);
        console.log("Using vrf Coordinator ", vrfCoordinator);
        console.log("On CHainID: ", block.chainid);

        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint64 subId,
        uint256 deployerKey
    ) public {
        console.log("Adding Consumer Contract");
        console.log("Using vrfcoordinator", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();

        (
            ,
            ,
            address vrfCoordinatior,
            ,
            ,
            uint64 subId,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(raffle, vrfCoordinatior, subId, deployerKey);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "MyContract",
            block.chainid
        );

        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
