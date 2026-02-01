// SPDX-License-Identifier: UNLICENSED

// Layout of Contract:
// license
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

pragma solidity 0.8.19;
import {
    VRFConsumerBaseV2Plus
} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol";
import {
    VRFV2PlusClient
} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    error Raffle__sendmoretoraffle();
    error Raffle__Transferfailed();
    error Raffle__NOtopen();
    error Raffle__upkeepNotneeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant requestConfirmations = 3;
    uint32 private constant numWords = 1;
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    uint256 private immutable i_interaval;
    uint256 private s_lasttimestamp;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address private s_recentwinner;
    RaffleState private s_rafflestate;

    event raffleEntered(address indexed player);
    event winnerpicked(address indexed winner);
    event requestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interaval = interval;
        s_lasttimestamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_rafflestate = RaffleState.OPEN;
    }

    function enterraffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__sendmoretoraffle();
        }
        if (s_rafflestate != RaffleState.OPEN) {
            revert Raffle__NOtopen();
        }

        s_players.push(payable(msg.sender));
        emit raffleEntered(msg.sender);
    }

    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool timePassed = ((block.timestamp - s_lasttimestamp) >= i_interaval);
        bool isOpen = (s_rafflestate == RaffleState.OPEN);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
        return (upkeepNeeded, "");
    }

    function performUpkeep(
        bytes calldata /* performData */
    )
        external
    {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__upkeepNotneeded(address(this).balance, s_players.length, uint256(s_rafflestate));
        }
        s_rafflestate = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: requestConfirmations,
            callbackGasLimit: i_callbackGasLimit,
            numWords: numWords,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit requestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256,
        /*requestId*/
        uint256[] memory randomWords
    )
        internal
        override
    {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentwinner = recentWinner;
        s_rafflestate = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lasttimestamp = block.timestamp;
        emit winnerpicked(s_recentwinner);
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__Transferfailed();
        }
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffeleState() public view returns (RaffleState) {
        return s_rafflestate;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return s_players[index];
    }
    function getlasttimestamp() public view returns (uint256) {
        return s_lasttimestamp;
    }
    function getrecentwinner() public view returns (address) {
        return s_recentwinner;
    }
}
