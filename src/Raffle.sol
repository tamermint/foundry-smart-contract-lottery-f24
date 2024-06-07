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
contract Raffle is VRFConsumerBaseV2 {
    /**CUSTOM ERRORS */
    error Raffle__NotEnoughEthSent();
    error Raffle__NotEnoughTimeHasPassed();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    /**TYPE DECLARATION */
    enum RaffleState {
        OPEN, //0
        CALCULATING //1
    }

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
    address private s_recentWinner; //keep track of recent winner
    RaffleState private s_raffleState; //to store the state of the raffle

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    /**EVENTS */
    event EnteredRaffle(address indexed player);
    event WordsRequested(uint256 indexed requestid, uint32 numwords);
    event WordsReceived(uint256 requestId, uint256[] randomWords);
    event PickedWinner(address indexed player);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp; //the initial timestamp
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev This function implements the chainlink keepers automation. It needs to check
     * whether an upkeep is needed. So perform upkeep only when
     * 1. time interval has passed
     * 2. there is enough eth in the contract
     * 3. raffle state is open
     * 4. Implicitly - subscription needs to be funded
     */

    function checkUpKeep(
        //we are not importing the automation compatible so writing this differently
        bytes memory /*check Data*/
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool hasTimePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (hasTimePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpKeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        //set the raffle state
        s_raffleState = RaffleState.CALCULATING;
        //two things to do here->
        //1. generate a random number
        s_requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit WordsRequested(s_requestId, NUM_WORDS);
        //2. Pick winner
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        //now we need to pick winner -> using modulo
        emit WordsReceived(requestId, randomWords);
        //once word (big large number) is received, divide by length of array
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        //reset the players array so we have a new pool of players
        s_players = new address payable[](0);
        //reset the clock
        s_lastTimeStamp = block.timestamp;

        //now pay the winner
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit PickedWinner(winner);
    }

    /**Getter Functions */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }
}
