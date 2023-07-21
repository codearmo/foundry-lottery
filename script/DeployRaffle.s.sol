// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription} from "./Interactions.s.sol";
import {FundSubscription, AddConsumer, CreateSubscription} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle raffle, HelperConfig helperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinatior,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(
                vrfCoordinatior,
                deployerKey
            );

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinatior,
                subscriptionId,
                link,
                deployerKey
            );
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            vrfCoordinatior,
            gasLane,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            vrfCoordinatior,
            subscriptionId,
            deployerKey
        );

        return (raffle, helperConfig);
    }
}
