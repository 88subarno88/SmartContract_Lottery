//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {Test} from "../../lib/forge-std/src/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Deployraffle} from "../../script/Deployraffle.s.sol";
import {Helperconfig} from "../../script/Helperconfig.s.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";   

contract RaffelTest is Test {
    Raffle public raffle;
    Helperconfig public helperconfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant Estarting_player_balance = 10 ether;

    event raffleEntered(address indexed player);
    event winnerpicked(address indexed winner);

    function setUp() external {
        Deployraffle deployraffle = new Deployraffle();
        (raffle, helperconfig) = deployraffle.deploycontract();
        Helperconfig.NetworkConfig memory config = helperconfig.getconfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;         
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        vm.deal(PLAYER, Estarting_player_balance);
       
        // vm.deal(USER, Estarting_player_balance);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffeleState() == Raffle.RaffleState.OPEN);
    }

    function testraffelrevertsifnotenougheth() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__sendmoretoraffle.selector);
        raffle.enterraffle();
    }
    function testraffelrecordsplayerwhentheyenter() public {
        vm.prank(PLAYER);
        raffle.enterraffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testenteringraffelemitsevent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit raffleEntered(PLAYER);
        raffle.enterraffle{value: entranceFee}();
    }
    modifier Raffleenter {
        vm.prank(PLAYER);
        raffle.enterraffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
        
    }
    function testdonotallowplayersfromenteringwhenraffleiscalculating() public Raffleenter{
        // vm.prank(PLAYER);
        // raffle.enterraffle{value: entranceFee}();
        // vm.warp(block.timestamp + interval + 1);
        // vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__NOtopen.selector);
        vm.prank(PLAYER);
        raffle.enterraffle{value: entranceFee}();
    }

    function testupkeepreturnsfalseifnoplayers() public {
        vm.prank(PLAYER);
        raffle.enterraffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
    }

    function testcheckupreturnsfalseifraffleisnotopen() public {
        vm.prank(PLAYER);
        raffle.enterraffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }
    function testperformupkeeponlyrunifcheckupistrue() public {
        vm.prank(PLAYER);
        raffle.enterraffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
    }
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
       Raffle.RaffleState rState = raffle.getRaffeleState();

        vm.prank(PLAYER);
        raffle.enterraffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers =1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__upkeepNotneeded.selector,
                currentBalance,
                numPlayers, 
                rState
            )
        );
        raffle.performUpkeep("");
    }
    function testPerformupkeepupdateraffelstateandemitsrequestid() public {
        vm.prank(PLAYER);
        raffle.enterraffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();     
        bytes32 requestIdTopic = entries[1].topics[0];
        assert(uint256(requestIdTopic) > 0);
        Raffle.RaffleState rState = raffle.getRaffeleState();
        assert(uint256(rState) == 1);
    }
    function testfullfillrandomwordscanonlybecalledafterperformupkeep(uint256 randomRequestId) public Raffleenter {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
     
    }  
    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public Raffleenter {
        // Arrange
        uint256 additionalEntrants = 3; // 4 total
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            // FIX: Changed 'enterRaffle' to 'enterraffle' (lowercase r) to match your contract
            raffle.enterraffle{value: entranceFee}();
        }
        
        // Note: Ensure your Raffle.sol has these getter functions: getLastTimeStamp() and getRecentWinner()
        // If not, you might need to add them to your main contract.
        uint256 startingTimeStamp = raffle.getlasttimestamp();
        uint256 winnerstartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        address recentWinner = raffle.getrecentwinner();
        Raffle.RaffleState rState = raffle.getRaffeleState();
        uint256 winnerEndingBalance = recentWinner.balance; 
        uint256 endingTimeStamp = raffle.getlasttimestamp();
        uint256 price = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        // FIX: Changed 'raffleState' to 'rState'
        assert(uint256(rState) == 0);
        assert(winnerEndingBalance == winnerstartingBalance + price);
        assert(endingTimeStamp > startingTimeStamp);
    }
}