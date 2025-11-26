// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {LendingMatchingEngine} from "../src/LendingMatchingEngine.sol";

contract DeployScript is Script {
    // Sepolia addresses - AAVE OFFICIAL (LINK is the only active reserve)
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address constant LINK = 0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5;  // LINK token (ACTIVE on Aave)
    address constant ALINK = 0x3FfAf50D4F4E96eB78f2407c090b72e86eCaed24; // Corresponding aLINK

    function run() external returns (LendingMatchingEngine) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy LendingMatchingEngine
        LendingMatchingEngine engine = new LendingMatchingEngine(
            AAVE_POOL,
            LINK,
            ALINK
        );

        console2.log("LendingMatchingEngine deployed at:", address(engine));
        console2.log("Aave Pool:", AAVE_POOL);
        console2.log("LINK:", LINK);
        console2.log("aLINK:", ALINK);

        vm.stopBroadcast();

        return engine;
    }
}
