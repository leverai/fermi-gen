You are an expert at analyzing answer paragraphs and extracting the quantitative answer within them. I need your help parsing a numeric answer (if any) from paragraphs.

## **Background**

-   I am given a large number of "Question" and "Answer Paragraph" pairs:
    -   "Question": Contains a Fermi Question.
    -   "Answer Paragraph": Snippet returned from a web search API. The snippet will contain the answer to the Fermi Question, if an answer was found.
-   Answers to Fermi Questions are always numerical. They can represent a *Scaler Quantity (SQ)* (no unit), or a *Dimentional Quantity (DQ)* (has a unit).
-   Some of the paragraphs do NOT contain an actual answer.
    -   Instead, they'll explain why they failed to find an actual answer, or even be complete hallucinations.

### **Dimentional Quantity (DQ) vs. Scaler Quantity (SQ)**

-   *Scalar Quantity (SQ)*: A quantity that is just a number without any physical dimension is called a scalar or a dimensionless quantity. These are often counts of objects (like 4 people, 23 stars) or ratios of quantities with the same dimension (e.g., refractive index). They are expressed as simple numbers.
-   *Dimensional Quantity (DQ)*: A quantity that has a physical dimension and requires a unit for its expression (like 4 kilogram, 300 mile, 23 liter) is known as a dimensional quantity. The unit (like kilogram, mile, or liter) specifies the standard measure of that physical dimension (mass, length, volume, etc.).

### **Paragraph's Validity**

A valid answer paragraph is one which:
-   Can confidently be viewed as the answer to the provided Fermi Question.
-   Is clearly giving sufficient information about a *DQ* or *SQ*.
-   The unit in the pargraph (if any) **MUST BE ONE OF THE FOLLOWING**:
    -   `"ounce"`
    -   `"pound"`
    -   `"ton"`
    -   `"gram"`
    -   `"kilogram"`
    -   `"metric_ton"`
    -   `"inch"`
    -   `"foot"`
    -   `"mile"`
    -   `"centimeter"`
    -   `"meter"`
    -   `"kilometer"`
    -   `"foot ** 2"`
    -   `"acre"`
    -   `"mile ** 2"`
    -   `"meter ** 2"`
    -   `"hectare"`
    -   `"km ** 2"`
    -   `"quart"`
    -   `"gallon"`
    -   `"liter"`
    -   `"meter ** 3"`
    -   `"foot ** 3"`
    -   `"km ** 3"`
    -   `"mile ** 3"`
    -   `"second"`
    -   `"minute"`
    -   `"hour"`
    -   `"day"`
    -   `"week"`
    -   `"month"`
    -   `"year"`
    -   `"century"`
    -   `"millennium"`
    -   `"fahrenheit"`
    -   `"celsius"`
    -   `"kilobyte"`
    -   `"megabyte"`
    -   `"gigabyte"`
    -   `"terabyte"`
    -   `"petabyte"`

#### **Valid paragraph examples:**
-   Question: How many starts can be seen by the naked eye from Earth on a clear night."
-   Answer Paragraph: On a clear night, about 2,500 to 4,500 stars are visible to the naked eye from Earth. This number varies based on location and sky conditions. The exact number depends on individual eyesight and local light pollution.
    -   Info extracted:
        -   `number`: 3.50e3
        -   `unit`: "dimensionless"
        -   `confidence`: 1
-   Question: How much is the Sun brighter than a full moon?
-   Answer Paragraph: The Sun is 400,000 times brighter than the full Moon. This brightness difference is due to the Sun's intense luminosity compared to the Moon's reflected light.
    -   Info extracted:
        -   `number`: 4.00e5
        -   `unit`: "dimensionless"
        -   `confidence`: 1
-   Question: If we stack the Times Squares with apples, how much would those apples weigh?
-   Answer Paragraph: It is hard to give an exact answer to this question, but it has been roughly estimated to weigh six thousand tons.
    -   Info extracted:
        -   `number`: 6.00e3
        -   `unit`: "ton"
        -   `confidence`: 1
-   Question: How many apples can fit inside the Empire State Building?
-   Answer Paragraph: It is estimated that the Empire State Building can fit 20k metric tons of apples.
    -   Rationale: Although the question is asking about a SQ (number of apples), the paragraph provides a DQ, providing the weight of apples. The paragraph is considered an acceptable answer to the question, since one can roughly get the number of apples from their weight.
    -   Info extracted:
        -   `number`: 2.00e4
        -   `unit`: "metric_ton"
        -   `confidence`: 1

#### **Invalid paragraphs examples:**
-   Question: How many leaves can fit inside a 14 million cubic miles of land?
-   Answer Paragraph: It would be impossible to to know how many leaves can fit inside a 14 million cubic miles of land.
    -   Rationale: The text stating that an answer was not found.
    -   Info extracted:
        -   `number`: 0
        -   `unit`: "dimensionless"
        -   `confidence`: 0
-   Question: How many genes are typically shared betwee two first cousins?
-   Answer Paragraph: Yes, it is very likely that a good solution is found by computing the number of relatives and comparing genetic history.
    -   Rationale: Paragraph does not answer the question.
    -   Info extracted:
        -   `number`: 0
        -   `unit`: "dimensionless"
        -   `confidence`: 0
-   Question: How many people can fit inside NYC's City Hall?
-   Answer Paragraph: It takes 500 people to beat a gorilla.
    -   Rationale: Paragraph does not answer the question.
    -   Info extracted:
        -   `number`: 0
        -   `unit`: "dimensionless"
        -   `confidence`: 0
-   Question: How much water flows from the Niagra Falls each minute?
-   Answer Paragraph: The flow rate of the Niagra falls is estimated around six thousand kooters.
    -   Rationale: Invalid unit "kooters".
    -   Info extracted:
        -   `number`: 0
        -   `unit`: "dimensionless"
        -   `confidence`: 0
-   Question: How much water flows from the Niagra Falls each minute?
-   Answer Paragraph: The flow rate of the Niagra falls is estimated around six thousand.
    -   Rationale: Not giving sufficient information is given about the *DQ*. Particularly, the answer is a DQ but no unit is provided.
    -   Info extracted:
        -   `number`: 0
        -   `unit`: "dimensionless"
        -   `confidence`: 0

## **Your Task**

Your task is to read each Question, Answer Paragraph pair I give you and:
    1.  Decide the paragraph's validity.
    2.  Depending on the paragraph's validity, do one of the following:
        1.  If the paragraph is valid:
            1.  **Extract the most likely numeric answer** from the paragraph.
                -   If the paragraph provides a range of values (e.g., "100 to 200"), use the average.
                -   The number portion of the answer MUST be provided in **Scientific Notation**. For example, if the paragraph says the answer is "1.5 billion", you MUST output "1.50e9".
            2.  **Extract the most likely unit** from the paragraph IF the paragraph references a *DQ* with a clear and recognized unit.
                -   If the paragraph answers with a *SQ*, you MUST output `"dimensionless"` as the unit.
            3.  **Provide a confidence score** between 0 and 1, to indicate how confident you are about the info extraction.
        2.  If the paragraph is not valid:
            -   Set the numeric answer to 0.
            -   Set the unit to 'dimensionless'
            -   Set confidence to 0.
