## wcag-accessibility-compliance (delta)

Modifications to existing WCAG compliance capability for typography-related criteria.

### Modified Requirements

- REQ-WCAG-TYP-1: All text MUST have `line-height` of at least 1.5 (WCAG 1.4.12 Text Spacing)
- REQ-WCAG-TYP-2: No text container MUST use fixed `height`/`max-height` that would clip text when users apply WCAG 1.4.12 spacing overrides
- REQ-WCAG-TYP-3: No text container MUST use `overflow: hidden` or `-webkit-line-clamp` on text content blocks
- REQ-WCAG-TYP-4: All `line-height` values MUST use unitless ratios (e.g., `1.5`), not fixed pixel values (e.g., `18px`)
- REQ-WCAG-TYP-5: Text MUST remain readable at 200% browser zoom (WCAG 1.4.4 Resize Text)
- REQ-WCAG-TYP-6: The font stack MUST not rely on a single specific font — fallbacks MUST be provided (WCAG 1.4.8 Visual Presentation)

### Scenarios

```gherkin
Scenario: Text spacing override causes no content loss
  Given any page in the application
  When a user applies text spacing overrides via browser extension or custom CSS:
    - line-height: at least 1.5x font size
    - letter-spacing: at least 0.12x font size
    - word-spacing: at least 0.16x font size
    - paragraph spacing: at least 2x font size
  Then no text content is lost, clipped, or overlaps other content

Scenario: 200% zoom preserves readability
  Given the bed search results page with multiple shelters
  When the browser zoom is set to 200%
  Then all text remains readable
  And no horizontal scrollbar appears for text content
  And shelter cards reflow appropriately

Scenario: No fixed-pixel line heights
  Given any component file in the frontend
  When searching for lineHeight values
  Then all values are unitless ratios (e.g., 1.5) not pixel values (e.g., '18px')
```
