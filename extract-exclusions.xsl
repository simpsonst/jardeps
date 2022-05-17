<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		version="1.0"
		xmlns="http://www.w3.org/1999/02/22-rdf-syntax-ns#" 
		xmlns:em="http://www.mozilla.org/2004/em-rdf#">
  <xsl:output method="text" encoding="UTF-8" />

  <xsl:template match="/classpath/classpathentry">
    <xsl:if test="@path=$ROOT">
      <xsl:value-of select="@excluding" />
      <xsl:text>&#10;</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="text()" />
</xsl:stylesheet>
