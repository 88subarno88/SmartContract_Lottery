//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {Helperconfig} from "./Helperconfig.s.sol";
// FIX: Changed fundsubscription to FundSubscription (Capital S)
import {Createsubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract Deployraffle is Script {
    function run() public {
        deploycontract();
    }

    function deploycontract() public returns (Raffle, Helperconfig) {
        Helperconfig helperconfig = new Helperconfig();
        Helperconfig.NetworkConfig memory config = helperconfig.getconfig();

        if (config.subscriptionId == 0) {
            // FIX: Renamed variable to 'createSub' to avoid shadowing the contract name
            Createsubscription createSub = new Createsubscription();
            (config.subscriptionId, config.vrfCoordinator) = createSub.createSubscription(config.vrfCoordinator,config.account);
        }

        // FIX: Changed to FundSubscription (Capital S)
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundsubscription(config.vrfCoordinator, config.subscriptionId, config.link, config.account);

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addconsumer = new AddConsumer();
        addconsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, config.account );

        return (raffle, helperconfig);
    }
}
