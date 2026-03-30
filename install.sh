#!/bin/bash
# Winnr Claude Code Skills — Installer
# https://github.com/winnr-app/winnr-claude-skills

set -e

REPO="winnr-app/winnr-claude-skills"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
SKILLS_DIR="${HOME}/.claude/skills"

SKILLS=(
  "winnr"
  "winnr-setup"
  "winnr-health"
  "winnr-troubleshoot"
  "winnr-scale"
  "winnr-export"
)

echo ""
echo "  Winnr Claude Code Skills"
echo "  ========================"
echo ""

# Create skills directory
mkdir -p "${SKILLS_DIR}"

# Download each skill
for skill in "${SKILLS[@]}"; do
  dir="${SKILLS_DIR}/${skill}"
  mkdir -p "${dir}"
  echo "  Installing ${skill}..."
  curl -sL "${BASE_URL}/skills/${skill}/SKILL.md" -o "${dir}/SKILL.md"
done

echo ""
echo "  Installed ${#SKILLS[@]} skills to ${SKILLS_DIR}/"
echo ""

# Check if winnr-mcp is configured
MCP_CONFIGURED=false

# Check Claude Code MCP config
if command -v claude &>/dev/null; then
  if claude mcp list 2>/dev/null | grep -q "winnr"; then
    MCP_CONFIGURED=true
  fi
fi

# Check Claude Desktop config
CLAUDE_DESKTOP_CONFIG="${HOME}/Library/Application Support/Claude/claude_desktop_config.json"
if [ -f "${CLAUDE_DESKTOP_CONFIG}" ] && grep -q "winnr" "${CLAUDE_DESKTOP_CONFIG}" 2>/dev/null; then
  MCP_CONFIGURED=true
fi

# Check Cursor config
if [ -f ".cursor/mcp.json" ] && grep -q "winnr" ".cursor/mcp.json" 2>/dev/null; then
  MCP_CONFIGURED=true
fi

if [ "${MCP_CONFIGURED}" = true ]; then
  echo "  MCP server: winnr-mcp detected"
else
  echo "  MCP server: winnr-mcp not detected"
  echo ""
  echo "  The Winnr skills require the winnr-mcp MCP server."
  echo "  Set it up with:"
  echo ""
  echo "    claude mcp add winnr -- uvx winnr-mcp"
  echo ""
  echo "  You'll need a Winnr API token from:"
  echo "    https://app.winnr.app → Settings → API Tokens"
fi

echo ""
echo "  Quick start:"
echo "    /winnr status       — Check your account"
echo "    /winnr setup        — Set up new infrastructure"
echo "    /winnr health       — Run a health check"
echo ""
echo "  Full docs: https://winnr.app/skills.html"
echo ""
