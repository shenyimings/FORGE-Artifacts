// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./lib/Pausable.sol";
import "./lib/ISignatureTransfer.sol";

contract CanxiumBridge is AccessControl, Pausable {
    struct Transfer {
        address token;
        address receiver;
        uint amount;
        // block number where this release request is submited
        uint blockNumber;
    }

    // max hot balance %
    uint private maxHotBalancePercent = 30;
    // number of safety block to be enabled to claim after release is submitted
    uint private safeBlock = 10;

    // max coin or token can be accessed by hot wallet
    mapping(address => uint) private hotBalances;

    // history of release cau/token, map from tx hash to block number
    mapping(bytes32 => uint) private claimed;

    // map of transfer request to be released;
    // to release coin/token for a transfer request, operator have to submit a release transaction. Then
    // another transaction have to be submited later more than 10 block to claim the coin or token
    mapping(bytes32 => Transfer) public releaseQueue;

    // Permit2 interface
    // 0xF80c91442D3EF66632958C0d395667075FC82fB0: Canxium
    // 0x000000000022D473030F116dDEE9F6B43aC78BA3: Ethereum
    ISignatureTransfer private permit2 = ISignatureTransfer(0xF80c91442D3EF66632958C0d395667075FC82fB0);
    
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant SAFEGUARD_ROLE = keccak256("SAFEGUARD_ROLE");

    // user events
    event TransferToken(address token, address receiver, uint amount, uint32 chainId);

    event Claim(address indexed token, address indexed receiver, uint indexed amout, bytes32 txHash);
    event Release(uint indexed chainId, bytes32 indexed txHash, address token, address receiver, uint amount);

    constructor(address owner, address operator, address guarder) payable {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(OPERATOR_ROLE, operator);
        _grantRole(SAFEGUARD_ROLE, guarder);
    }

    // #### PUBLIC FUNC #### //
    
    // transfer cau/crc20 token to other chain
    function transfer(
        uint32 chainId,
        address token,
        uint amount,
        address receiver,
        // permit2 params
        uint256 nonce,
        uint256 deadline,
        bytes calldata sig
    ) public payable whenNotPaused() {
        // transfer cau
        uint maxBalance = 0;
        if (token == address(0)) {
            require(msg.value > 0, "You have to deposit a positive amount");
            maxBalance = address(this).balance * maxHotBalancePercent / 100;
        } else {
            require(msg.value == 0, "Deposit native coin for this token transfer is not allowed");
            // transfer the token amount back to this contract address
            permit2.permitTransferFrom(
                ISignatureTransfer.PermitTransferFrom({
                    permitted: ISignatureTransfer.TokenPermissions({
                        token: token,
                        amount: amount
                    }),
                    nonce: nonce,
                    deadline: deadline
                }),
                ISignatureTransfer.SignatureTransferDetails({
                    to: address(this),
                    requestedAmount: amount
                }),
                msg.sender,
                sig
            );

            IERC20 iToken = IERC20(token);
            maxBalance = iToken.balanceOf(address(this)) * maxHotBalancePercent / 100;
        }

        // increase hot balance if it not reach 30% of total balance of contract
        hotBalances[token] = hotBalances[token] + amount;
        if (hotBalances[token] > maxBalance) {
            hotBalances[token] = maxBalance;
        }

        emit TransferToken(token, receiver, amount, chainId);
    }

    // release coin/token for the information already submit 10 blocks before
    // any one can request to release coin/token after operator submited these info 10 blocks ago.
    function claim(bytes32 txHash) public whenNotPaused() {
        require(claimed[txHash] == 0, "Already release for this transaction hash");
        claimed[txHash] = block.number;

        require(releaseQueue[txHash].blockNumber > 0, "Not found in release queue");
        require(block.number - releaseQueue[txHash].blockNumber > safeBlock, "Confirmation block is not met");
        
        address token = releaseQueue[txHash].token;
        address receiver = releaseQueue[txHash].receiver;
        uint amount = releaseQueue[txHash].amount;
        require(hotBalances[token] >= amount, "Insufficient hot balance");

        if (token == address(0)) {
            payable(receiver).transfer(amount);
        } else {
            IERC20 iToken = IERC20(token);
            iToken.transfer(receiver, amount);
        }

        hotBalances[token] = hotBalances[token] - amount;
        delete releaseQueue[txHash];
        emit Claim(token, receiver, amount, txHash);
    }

    // deposit wrap token to be released for users who bridge token from other chains
    // we pre-mint some token by cold address and deposit to this contract to be released by hot wallet for more secure.
    // Do not deposit your own token.
    function deposit(address token, uint amount) public whenNotPaused() {
        require(token != address(0), "Deposit wrap token address");
        IERC20 iToken = IERC20(token);
        require(iToken.transferFrom(msg.sender, address(this), amount), "Insufficient allowance token balance");
        uint maxBalance = iToken.balanceOf(address(this)) * maxHotBalancePercent / 100;
        hotBalances[token] = hotBalances[token] + amount;
        if (hotBalances[token] > maxBalance) {
            hotBalances[token] = maxBalance;
        }
    }

    // return hot balance of a token
    function hotBalance(address token) public view returns (uint) {
        return hotBalances[token];
    }

    // is this tx hash have been claimed
    function claimedAt(bytes32 txHash) public view returns (uint) {
        return claimed[txHash];
    }

    // which block operator released transfer
    function releasedAt(bytes32 txHash) public view returns (uint) {
        return releaseQueue[txHash].blockNumber;
    }

    // #### OPERATOR FUNC (HOT WALLET) #### //

    // submit transfer information to be release in next 10 blocks
    function release(uint chainId, bytes32 txHash, address token, address receiver, uint amount) public onlyRole(OPERATOR_ROLE) whenNotPaused() {
        require(claimed[txHash] == 0, "Already released for this transaction hash");
        require(releaseQueue[txHash].blockNumber == 0, "Already in release queue");

        releaseQueue[txHash] = Transfer(token, receiver, amount, block.number);
        emit Release(chainId, txHash, token, receiver, amount);
    }

    // #### SafeGuard Func #### //
    // Guarder will monitor for release transaction, if it found an invalid transaction, it will pause this contract immediately
    // attacker have to wait 10 blocks to release the coin/token so we can pause the contract before he withdraw the money
    // Guarder can be hot wallet, or cold wallet with pre-sign transaction ready to send to the blockchain
    function pause() public onlyRole(SAFEGUARD_ROLE) {
        _pause();
    }

    // #### OWNER FUNC (COLD WALLET) #### //

    // approve more balance for hot wallet
    function approve(address token, uint amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint balance = address(this).balance;
        if (token != address(0)) {
            IERC20 iToken = IERC20(token);
            balance = iToken.balanceOf(address(this));
        }

        require(amount <= balance, "Insufficient aprroved amout");
        hotBalances[token] = amount;
    }

    // revert data submited by operator
    function revertRelease(bytes32 txHash) public onlyRole(DEFAULT_ADMIN_ROLE) {
        delete releaseQueue[txHash];
    }

    function setMaxHotBalance(uint percent) public onlyRole(DEFAULT_ADMIN_ROLE) {
        maxHotBalancePercent = percent;
    }

    function withdraw(address token) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) {
            payable(msg.sender).transfer(address(this).balance);
        }

        IERC20 iToken = IERC20(token);
        iToken.transfer(msg.sender, iToken.balanceOf(address(this)));
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
