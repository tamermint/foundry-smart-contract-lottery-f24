// Layout of Contract:
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * @title Smart Contract Lottery
 * @author Vivek Mitra
 * @notice Script to emulate a decentralised lottery
 * @dev Implements Chainlink VRFv2
 */
abstract contract Raffle is VRFConsumerBaseV2 {
    /**CUSTOM ERRORS */
    error Raffle_NotEnoughEthSent();
    error Raffle_NotEnoughTimeHasPassed();

    /**STATE VARIABLES */
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator; //getting a co-ordinator object to perform the requests
    uint256 private immutable i_entranceFee; //entrance fee is set once - constructor initializes this
    uint256 private immutable i_interval; //set the interval after which the lottery must pick a winner
    bytes32 private immutable i_gasLane; //to limit the gas to be spent
    uint64 private immutable i_subscriptionId; //our subscription id
    uint32 private immutable i_callbackGasLimit; //gas to pay for response

    address payable[] private s_players; //to store the list of players who entered the game and also pay them if one of them is the winner
    //@dev Duration of the lottery in seconds
    uint256 private s_lastTimeStamp; //last timestamp

    uint256 private s_requestId; //store the request sent back from the co-ordinator

    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    uint32 private constant NUM_WORDS = 1;

    /**EVENTS */
    event EnteredRaffle(address indexed player);
    event WordsRequested(uint256 indexed requestid);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp; //the initial timestamp
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle_NotEnoughEthSent();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() public {
        //check whether enough time has passed
        //logic is block.timestamp - lastTimeStamp >= i_interval then we pick winner
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert Raffle_NotEnoughTimeHasPassed();
        }
        //two things to do here->
        //1. generate a random number
        s_requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit WordsRequested(s_requestId);
        //2. Pick winner
    }

    /**Getter Function */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
