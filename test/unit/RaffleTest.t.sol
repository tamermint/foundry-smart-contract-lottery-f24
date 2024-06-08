// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

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
            link
        ) = helperConfig.activeNetworkConfig();
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    //Enter Raffle

    function testRaffleFailsWhenYouDontPayEnough() public {
        //Arrange
        vm.prank(PLAYER);

        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector); //the next line will revert
        //Assert/Act
        raffle.enterRaffle();
    }

    modifier funded() {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        _;
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public funded {
        //Arrange
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0); //the prank and deal are scoped to this so whenever this unit test runs, its only the first player
        //Assert
        assert(playerRecorded == PLAYER);
    }

    function testRaffleEmitsEventOnEntrace() public funded {
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public funded {
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); //moves time forward in the chain and + 1 is just a sanity check
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
    }
}
