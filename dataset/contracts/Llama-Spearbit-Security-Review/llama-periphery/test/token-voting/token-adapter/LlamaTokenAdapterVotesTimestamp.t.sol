// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

import {LlamaTokenVotingTestSetup} from "test/token-voting/LlamaTokenVotingTestSetup.sol";
import {LlamaCoreSigUtils} from "test/utils/LlamaCoreSigUtils.sol";

import {ILlamaTokenAdapter} from "src/token-voting/interfaces/ILlamaTokenAdapter.sol";
import {LlamaTokenAdapterVotesTimestamp} from "src/token-voting/token-adapters/LlamaTokenAdapterVotesTimestamp.sol";

contract LlamaTokenAdapterVotesTimestampTest is LlamaTokenVotingTestSetup, LlamaCoreSigUtils {
  function setUp() public virtual override {
    LlamaTokenVotingTestSetup.setUp();

    // Mint tokens to tokenholders so that there is an existing supply.
    erc20VotesToken.mint(tokenHolder0, ERC20_CREATION_THRESHOLD);

    // Mine block so that the ERC20 and ERC721 supply will be available when doing a past timestamp check at initialize
    // during deployment.
    mineBlock();

    // Deploy ERC20 Token Voting Module.
    _deployERC20TokenVotingModuleAndSetRole();
  }
}

contract Constructor is LlamaTokenAdapterVotesTimestampTest {
  function test_RevertIf_InitializeImplementationContract() public {
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    bytes memory adapterConfig = abi.encode(LlamaTokenAdapterVotesTimestamp.Config(address(erc20VotesToken)));
    llamaTokenAdapterTimestampLogic.initialize(adapterConfig);
  }
}

contract Initialize is LlamaTokenAdapterVotesTimestampTest {
  function test_RevertIf_InitializeAlreadyInitializedContract() public {
    bytes memory adapterConfig = abi.encode(LlamaTokenAdapterVotesTimestamp.Config(address(erc20VotesToken)));
    bytes32 salt = keccak256(abi.encodePacked(address(EXECUTOR), address(CORE), adapterConfig, uint256(0)));

    ILlamaTokenAdapter llamaERC20TokenAdapter = ILlamaTokenAdapter(
      Clones.predictDeterministicAddress(
        address(llamaTokenAdapterTimestampLogic),
        salt,
        address(tokenVotingFactory) // deployer
      )
    );

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    llamaERC20TokenAdapter.initialize(adapterConfig);
  }
}
