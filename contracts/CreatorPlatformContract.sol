// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AuroraToken.sol";

/**
 * @title PlatformContract
 * @dev Manages user interactions, token purchases, creator registrations,
 *      content uploads, donations, and withdrawals.
 */
contract PlatformContract is Ownable {
    AuroraToken public auroraToken;
    uint256 public tokenPrice;

    struct Creator {
        string name;
        bool isRegistered;
    }

    struct Content {
        address creator;
        string ipfsHash;
        string title;
        string fileType;
        uint256 currentDonation;
        uint256 donatorsCount;
        string contentCategory;
    }

    mapping(address => Creator) public creators;
    mapping(string => Content[]) private contentByCategory;
    mapping(address => Content[]) private contentByCreator;
    mapping(address => mapping(string => uint256)) private contentIndexByHash; // Maps IPFS hash to content index
    mapping(address => mapping(uint256 => bool)) private donors; // Maps donor address and content index to donation status

    event CreatorRegistered(address indexed creatorAddress, string name);
    event ContentUploaded(address indexed creatorAddress, string ipfsHash, string title, string contentCategory);
    event DonationReceived(address indexed donor, address indexed creator, uint256 amount);
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);
    event Withdrawn(address indexed creator, uint256 amount);

    constructor(AuroraToken _auroraToken, uint256 _initialTokenPrice, address initialOwner)
        Ownable(initialOwner)
    {
        require(address(_auroraToken) != address(0), "Invalid token contract address");
        auroraToken = _auroraToken;
        tokenPrice = _initialTokenPrice;
    }

    function setTokenPrice(uint256 newTokenPrice) external onlyOwner {
        require(newTokenPrice > 0, "Token price must be greater than zero");
        tokenPrice = newTokenPrice;
    }

    function purchaseTokens() external payable {
        require(msg.value > 0, "You need to send some ETH");
        uint256 tokensToMint = (msg.value * 10 ** auroraToken.decimals()) / tokenPrice;
        require(tokensToMint > 0, "Insufficient ETH sent for any tokens");
        auroraToken.mintForPlatform(msg.sender, tokensToMint);
        emit TokensPurchased(msg.sender, tokensToMint, msg.value);
    }

    function registerCreator(string calldata _name) external {
        require(!creators[msg.sender].isRegistered, "Creator is already registered");
        require(bytes(_name).length > 0, "Name cannot be empty");

        creators[msg.sender] = Creator({
            name: _name,
            isRegistered: true
        });

        emit CreatorRegistered(msg.sender, _name);
    }

    function uploadContent(string calldata _ipfsHash, string calldata _title, string calldata _fileType, string calldata _contentCategory) external onlyRegisteredCreator {
        require(bytes(_ipfsHash).length > 0, "IPFS hash cannot be empty");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_contentCategory).length > 0, "Content category cannot be empty");

        uint256 contentIndex = contentByCreator[msg.sender].length;

        Content memory newContent = Content({
            creator: msg.sender,
            ipfsHash: _ipfsHash,
            title: _title,
            fileType: _fileType,
            currentDonation: 0,
            donatorsCount: 0,
            contentCategory: _contentCategory
        });

        contentByCategory[_contentCategory].push(newContent);
        contentByCreator[msg.sender].push(newContent);
        contentIndexByHash[msg.sender][_ipfsHash] = contentIndex;

        emit ContentUploaded(msg.sender, _ipfsHash, _title, _contentCategory);
    }

    function donate(address creatorAddress, uint256 tokenAmount, string calldata ipfsHash) external{
        require(creators[creatorAddress].isRegistered, "Recipient is not a registered creator");
        require(tokenAmount > 0, "Amount must be greater than zero");

        // Check the token allowance of the sender for this contract
        uint256 allowance = auroraToken.allowance(msg.sender, address(this));
        require(allowance >= tokenAmount, "Insufficient allowance for token transfer");

        // Perform token transfer
        require(auroraToken.transferFrom(msg.sender, creatorAddress, tokenAmount), "Token transfer failed");

        uint256 contentIndex = contentIndexByHash[creatorAddress][ipfsHash];
        require(contentIndex < contentByCreator[creatorAddress].length, "Content not found");

        Content storage content = contentByCreator[creatorAddress][contentIndex];

        // Update donation amount
        content.currentDonation += tokenAmount;

        // Update donator count if this is the first donation from this donor for this content
        if (!donors[msg.sender][contentIndex]) {
            content.donatorsCount += 1;
            donors[msg.sender][contentIndex] = true;
        }

        emit DonationReceived(msg.sender, creatorAddress, tokenAmount);
    }

    function approveTokens(uint256 tokenAmount) external {
        require(tokenAmount > 0, "Amount must be greater than zero");
        bool success = auroraToken.approve(address(this), tokenAmount);
        require(success, "Token approval failed");
    }

    function withdraw(uint256 tokenAmount) external  onlyRegisteredCreator {
        require(tokenAmount > 0, "Amount must be greater than zero");
        require(auroraToken.balanceOf(msg.sender) >= tokenAmount, "Insufficient token balance");
        uint256 totalEthAmount = (tokenAmount * tokenPrice) / (10 ** auroraToken.decimals());
        auroraToken.burnForPlatform(msg.sender, tokenAmount);
        uint256 ethToWithdraw = (totalEthAmount * 98) / 100;
        payable(msg.sender).transfer(ethToWithdraw);
        emit Withdrawn(msg.sender, ethToWithdraw);
    }

    modifier onlyRegisteredCreator() {
        require(creators[msg.sender].isRegistered, "Not registered as a creator");
        _;
    }

    receive() external payable {
        // ETH sent directly to the contract will not trigger token purchase
    }

    function withdrawETH() external onlyOwner  {
        payable(owner()).transfer(address(this).balance);
    }

    function getCreator(address _creatorAddress) external view returns (string memory name, bool isRegistered) {
        Creator memory creator = creators[_creatorAddress];
        return (creator.name, creator.isRegistered);
    }

    function getContentByCategory(string memory _category) external view returns (Content[] memory) {
        return contentByCategory[_category];
    }

    function getContentByCreator(address _creatorAddress) external view returns (Content[] memory) {
        return contentByCreator[_creatorAddress];
    }
}
