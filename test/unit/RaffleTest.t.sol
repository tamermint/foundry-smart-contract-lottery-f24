// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /**EVENTS */
    event EnteredRaffle(address indexed player); //have to redefine events as events are not structs that can be imported

    Raffle raffle;
    HelperConfig helperConfig;
    address public PLAYER = makeAddr("player");
    address public PLAYER2 = makeAddr("player2");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig();
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    //////////////////////////////
    //  ENTER RAFFLE /////////////
    //////////////////////////////

    function testRaffleFailsWhenYouDontPayEnough() public {
        //Arrange
        vm.prank(PLAYER);

        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector); //the next line will revert
        //Assert/Act
        raffle.enterRaffle();
    }

    modifier fundedAndTimePassed() {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public fundedAndTimePassed {
        address playerRecorded = raffle.getPlayer(0); //the prank and deal are scoped to this so whenever this unit test runs, its only the first player
        //Assert
        assert(playerRecorded == PLAYER);
    }

    function testRaffleEmitsEventOnEntrace() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public fundedAndTimePassed {
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
    }

    //////////////////////////////
    //  CHECK UPKEEP /////////////
    //////////////////////////////

    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleNotOpen()
        public
        fundedAndTimePassed
    {
        //Arrange
        raffle.performUpkeep("");

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    //////////////////////////////
    //  PERFORM UPKEEP ///////////
    //////////////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpKeepIsTrue()
        public
        fundedAndTimePassed
    {
        //Act/assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpKeepIsFalse() public {
        //Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;
        //Act/Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        fundedAndTimePassed
    {
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); //this emits the requestId
        Vm.Log[] memory entries = vm.getRecordedLogs(); //this is a way to store logs in a special data structure
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();

        // Assert
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    //////////////////////////////
    //  Fulfill Random Words /////
    //////////////////////////////

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulFillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public fundedAndTimePassed skipFork {
        //get VrfCoordinatorV2 mock to call the fulfill random words without checkupkeep
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    //////////////////////////////
    //  Complete Test of Raffle //
    //////////////////////////////

    function testFulfillRandomWordsPicksWinnerAndSendsMoney()
        public
        fundedAndTimePassed
        skipFork
    {
        //Arrange
        uint256 additionalEntrants = 5; //emulating additional entrants to the lottery
        uint256 startingIndex = 1; //starting index = 1 because 0 will give address 0 and it will not work because 1 person has already entered the Raffle

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i)); //generate addresses based off the number
            //such as address(1), address(2)...
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1); //determine prize money

        //now we need to be the chainlink vrf - request random words, fulfill and pick winner
        //1. request random words
        vm.recordLogs();
        raffle.performUpkeep(""); //this emits the requestId
        Vm.Log[] memory entries = vm.getRecordedLogs(); //this is a way to store logs in a special data structure
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        //2.Now we need to be the vrf coordinator
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        assert(uint256(raffle.getRaffleState()) == 0); //raffle should be open now
        assert(raffle.getRecentWinner() != address(0)); //checks that we have a winner
        assert(raffle.getLengthOfPlayers() == 0); //checks the length is reset after winner is picked
        assert(previousTimeStamp < raffle.getLastTimeStamp()); //check timestamp is less than current
        assert(
            raffle.getRecentWinner().balance ==
                STARTING_USER_BALANCE + prize - entranceFee
        ); //check that the winner has been paid
    }
}
