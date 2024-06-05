// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {Raffle} from "../src/Raffle.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle) {
        //here first check what the Raffle contract takes as params i.e. constructor
    }
}
