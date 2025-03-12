pragma solidity ^0.4.19;

import './TimeLockPool.sol';
import '../token/extentions/MintableToken.sol';
import '../math/SafeMath.sol';
import '../ownership/Ownable.sol';


/// @title A controller that manages permissions to mint specific ERC20/ERC223 token.
/// @author ICOVO AG
/// @dev The target must be a mintable ERC20/ERC223 and also be set its ownership
///      to this controller. It changes permissions in each 3 phases - before the
///      token-sale, during the token-sale and after the token-sale.
///     
///      Before the token-sale (State = Init):
///       Only the owner of this contract has a permission to mint tokens.
///      During the token-sale (State = Tokensale):
///       Only the token-sale contract has a permission to mint tokens.
///      After the token-sale (State = Public):
///       Nobody has any permissions. Will be expand in the future:
contract TokenController is Ownable {
    using SafeMath for uint256;

    MintableToken public targetToken;
    address public votingAddr;
    address public tokensaleManagerAddr;

    State public state;

    enum State {
        Init,
        Tokensale,
        Public
    }

    /// @dev The deployer must change the ownership of the target token to this contract.
    /// @param _targetToken : The target token this contract manage the rights to mint.
    /// @return 
    function TokenController (
        MintableToken _targetToken
    ) public {
        targetToken = MintableToken(_targetToken);
        state = State.Init;
    }

    /// @dev Mint and distribute specified amount of tokens to an address.
    /// @param to An address that receive the minted tokens.
    /// @param amount Amount to mint.
    /// @return True if the distribution is successful, revert otherwise.
    function mint (address to, uint256 amount) external returns (bool) {
        /*
          being called from voting contract will be available in the future
          ex. if (state == State.Public && msg.sender == votingAddr) 
        */

        if ((state == State.Init && msg.sender == owner) ||
            (state == State.Tokensale && msg.sender == tokensaleManagerAddr)) {
            return targetToken.mint(to, amount);
        }

        revert();
    }

    /// @dev Change the phase from "Init" to "Tokensale".
    /// @param _tokensaleManagerAddr A contract address of token-sale.
    /// @return True if the change of the phase is successful, revert otherwise.
    function openTokensale (address _tokensaleManagerAddr)
        external
        returns (bool)
    {
        require(msg.sender == owner);
        /* check if the owner of the target token is set to this contract */
        require(MintableToken(targetToken).owner() == address(this));
        require(state == State.Init);
        require(_tokensaleManagerAddr != address(0x0));

        tokensaleManagerAddr = _tokensaleManagerAddr;
        state = State.Tokensale;
        return true;
    }

    /// @dev Change the phase from "Tokensale" to "Public". This function will be
    ///      cahnged in the future to receive an address of voting contract as an
    ///      argument in order to handle the result of minting proposal.
    /// @return True if the change of the phase is successful, revert otherwise.
    function closeTokensale () external returns (bool) {
        require(state == State.Tokensale && msg.sender == tokensaleManagerAddr);

        state = State.Public;
        return true;
    }

    /// @dev Check if the state is "Init" or not.
    /// @return True if the state is "Init", false otherwise.
    function isStateInit () external constant returns (bool) {
        return (state == State.Init);
    }

    /// @dev Check if the state is "Tokensale" or not.
    /// @return True if the state is "Tokensale", false otherwise.
    function isStateTokensale () external constant returns (bool) {
        return (state == State.Tokensale);
    }

    /// @dev Check if the state is "Public" or not.
    /// @return True if the state is "Public", false otherwise.
    function isStatePublic () external constant returns (bool) {
        return (state == State.Public);
    }
}

