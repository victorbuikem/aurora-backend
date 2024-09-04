// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract AuroraToken is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    address public platformContract;

    constructor(address initialOwner)
        ERC20("AURORA", "AUR")
        ERC20Permit("AURORA") 
        Ownable(initialOwner) 
    {
        require(initialOwner != address(0), "Invalid initial owner address");
        _mint(initialOwner, 1000 * 10 ** decimals());
        transferOwnership(initialOwner);
    }

    function setPlatformContract(address _platformContract) external onlyOwner {
        require(_platformContract != address(0), "Invalid address");
        platformContract = _platformContract;
    }

    function mintForPlatform(address to, uint256 amount) external {
        require(msg.sender == platformContract, "Not authorized");
        _mint(to, amount);
    }

    function burnForPlatform(address account, uint256 amount) external {
        require(msg.sender == platformContract, "Not authorized");
        _burn(account, amount);
    }
}
