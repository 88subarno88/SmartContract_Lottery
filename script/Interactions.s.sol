// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Helperconfig, codeconstants} from "./Helperconfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/linkstoken.t.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract Createsubscription is Script {
    function createsubscriptionusingconfig() public returns (uint256, address) {
        Helperconfig helperconfig = new Helperconfig();
        address vrfCoordinator = helperconfig.getconfig().vrfCoordinator;
        address account = helperconfig.getconfig().account;
        (uint256 subId,) = createSubscription(vrfCoordinator, account);
        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator, address account) public returns (uint256, address) {
        console.log("Creating subscription on chainid:", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("subscription created with id:", subId);
        return (subId, vrfCoordinator);
    }

    function run() public {
        createsubscriptionusingconfig();
    }
}

contract FundSubscription is Script, codeconstants {
    uint256 constant FUND_AMOUNT = 3 ether;

    function run() external {
        fundsubscriptionusingconfig();
    }

    function fundsubscriptionusingconfig() public {
        Helperconfig helperconfig = new Helperconfig();
        address vrfCoordinator = helperconfig.getconfig().vrfCoordinator;
        uint256 subscriptionid = helperconfig.getconfig().subscriptionId;
        address linktoken = helperconfig.getconfig().link;
        address account = helperconfig.getconfig().account;
        // FIX: Ensure all 4 arguments are passed here
        fundsubscription(vrfCoordinator, subscriptionid, linktoken, account);
    }

    function fundsubscription(address vrfCoordinator, uint256 subscriptionid, address linktoken, address account) public {
        console.log("Funding subscription :", subscriptionid);
        console.log("On vrfCoordinator :", vrfCoordinator);
        console.log("On chainid :", block.chainid);

        if (block.chainid == LOCAL_CHAINID_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionid, FUND_AMOUNT * 100);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linktoken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionid));
            vm.stopBroadcast();
        }
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        Helperconfig helperConfig = new Helperconfig();
        uint256 subId = helperConfig.getconfig().subscriptionId;
        address vrfCoordinator = helperConfig.getconfig().vrfCoordinator;
        address account = helperConfig.getconfig().account;
        
        // FIX: Added 'account' as the 4th argument here
        addConsumer(mostRecentlyDeployed, vrfCoordinator, subId, account);
    }

    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId, address account) public {
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("To vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}