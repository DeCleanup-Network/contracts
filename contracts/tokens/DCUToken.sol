// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DCUToken is ERC20, Ownable {

    // Events for detailed tracking
    event DCUMinted(
        address indexed to,
        uint256 amount,
        uint256 newBalance,
        uint256 timestamp
    );
    
    event DCUBurned(
        address indexed from,
        uint256 amount,
        uint256 newBalance,
        uint256 timestamp
    );
    event TransferWhitelistUpdated(
        address indexed account,
        bool isWhitelisted,
        uint256 timestamp
    );
    event TGEStatusChanged(bool completed);

    address public immutable rewardLogicContract;
    uint256 public immutable maxSupply;
    bool public tgeCompleted;
    mapping(address => bool) public transferWhitelist;

    constructor(address _rewardLogicContract, uint256 _maxSupply) ERC20("DCU Token", "DCU") Ownable(msg.sender) {
        // Initial supply can be minted here if needed
        require(_rewardLogicContract != address(0), "Invalid RewardLogic address");
        rewardLogicContract = _rewardLogicContract;
        maxSupply = _maxSupply;
        tgeCompleted = false;

        // Add essential contracts to whitelist
        transferWhitelist[msg.sender] = true;
        transferWhitelist[_rewardLogicContract] = true;
    }

    // Modifier to restrict minting to only RewardLogic contract
    modifier onlyRewardLogic() {
    require(msg.sender == rewardLogicContract, "Only RewardLogic Contract can mint");
    _;
    }
    
    /**
     * @dev Set the TGE status
     * @param _tgeCompleted Whether the TGE is completed
     */
    function setTGEStatus(bool _tgeCompleted) external onlyOwner {
        tgeCompleted = _tgeCompleted;
        emit TGEStatusChanged(_tgeCompleted);
    }

    /**
     * @dev Override the transfer function to implement pre-TGE restrictions
     * @param to The address receiving tokens
     * @param value The amount of tokens to transfer
     * @return A boolean indicating if the transfer was successful
     */
    function transfer(address to, uint256 value) public override returns (bool) {
        require(canTransfer(msg.sender, to), "DCU: External transfers not allowed before TGE");
        return super.transfer(to, value);
    }
    
    /**
     * @dev Override the transferFrom function to implement pre-TGE restrictions
     * @param from The address sending tokens
     * @param to The address receiving tokens
     * @param value The amount of tokens to transfer
     * @return A boolean indicating if the transfer was successful
     */
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        require(canTransfer(from, to), "DCU: External transfers not allowed before TGE");
        return super.transferFrom(from, to, value);
    }
    
    /**
     * @dev Determines if a transfer is allowed based on TGE status and whitelist
     * @param from The address sending tokens
     * @param to The address receiving tokens
     * @return A boolean indicating if the transfer is allowed
     */
    function canTransfer(address from, address to) public view returns (bool) {
        if (tgeCompleted) {
            return true;
        }
        
        return transferWhitelist[from] || transferWhitelist[to];
    }

    /**
     * @dev Updates the transfer whitelist for an account
     * @param account The address to update
     * @param status The whitelist status to set
     * @return A boolean indicating success
     */
    function updateTransferWhitelist(address account, bool status) external onlyOwner returns (bool) {
        require(account != address(0), "Cannot update zero address");
        transferWhitelist[account] = status;
        emit TransferWhitelistUpdated(account, status, block.timestamp);
        return true;
    }

    function mint(address to, uint256 amount) external onlyRewardLogic returns (bool) {
        require(totalSupply() + amount <= maxSupply, "Max supply reached");
        _mint(to, amount);
        
        // Emit detailed minting event
        emit DCUMinted(
            to,
            amount,
            balanceOf(to),
            block.timestamp
        );
        
        return true;
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
        
        // Emit detailed burning event
        emit DCUBurned(
            from,
            amount,
            balanceOf(from),
            block.timestamp
        );
    }
}