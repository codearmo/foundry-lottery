//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
* @title Sample raffle
* @dev This is a sample raffle contract with Chainlink
* @author John

 */

import {VRFCoordinatorV2Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__notEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 numPlayers,
        uint256 state
    );

    // type declarations

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subsciptionId;
    uint32 private immutable i_callbackGasLimit;
    address private s_recentWinner;
    // duration of the lottery in seconds
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    RaffleState private s_raffleState;

    /** Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 _entranceFee,
        uint256 interval,
        address vrfCoordinatior,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatior) {
        i_entranceFee = _entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatior);
        i_gasLane = gasLane;
        i_subsciptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__notEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));

        emit EnteredRaffle(msg.sender);
    }

    // 1. Get a random number to pick a player
    // 2. be automaticalled called
    /**
    * @dev this is funciton that the chainlinkl automation nodes call to see if it is time to perform the upkeep
    * the following should be true for this to return true:
    * 1. the time interval has passed between raffle runs
    * 2. the raffle is in the OPEN state
    * 3. The contract must have ETH i.e. players
    * 4. implicit that the contrac is funded with LINK

     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, bytes("0x0"));
    }

    function performUpkeep(bytes calldata /*performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");

        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;

        // pick a random winner
        ///https://youtu.be/sas02qSFZ74?t=15099

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subsciptionId, // id funded with link to make requests
            REQUEST_CONFIRMATIONS, // number of block confirmations
            i_callbackGasLimit,
            NUM_WORDS // number of random numbers
        );

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        ///https://www.youtube.com/watch?v=sas02qSFZ74
        // s_players = 10
        // rng = 12
        // 12 % 10 = 2
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        emit PickedWinner(winner);

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    //** Getter functions */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLengthOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
