function getCard(){
    $.get("<%= Routes::Card %>",
        function(data) {
            $(".card").html(data);
        }
    );
}

function getComment() {
    var $area = $("#comment-area"),
        eid = $area.find("input[name='expr-comment-eid']").val(),
        ver = $area.find("input[name='expr-comment-version']").val();
    $.get("<%= Routes::Index %>comment/"+eid+"/"+ver,
        function(data) {
            $("#comment-list").html(data);
        }
    );
}

(function () {
    window.addEventListener("load", function () {
        var form = document.getElementById("needs-validation");
        if (form !== null && form !== undefined) {
            form.addEventListener("submit", function (event) {
                if (form.checkValidity() == false) {
                    form.classList.add("was-validated");
                    event.preventDefault();
                    event.stopPropagation();
                }
            }, false);
        }

        var alert = $("#alert-message");
        alert.hide();

        $("#expr-form").submit(function (event) {
            // Stop form from submitting normally
            event.preventDefault();
        
            var $form = $(this),
                phr = $form.find("input[name='fue-phrase']").val(),
                con = $form.find("textarea[name='fue-context']").val(),
                des = $form.find("textarea[name='fue-description']").val(),
                eid = parseInt($form.find("input[name='fue-id']").val()),
                url = $form.attr("action");
        
            if (this.checkValidity() == false) {
                $form.classList.add("was-validated");
                event.stopPropagation();
            }
            // Send the data using post
            var posting = $.post(url, {
                phrase: phr,
                context: con,
                description: des,
                expr_id: eid
            });
        
            posting.done(function (data) {
                var result = JSON.parse(data);
                if (result["result"] === "ok") {
                    window.location.href = result["goto"];
                } else {
                    alert.html(result["message"]);
                    alert.show();
                }
            });
        });

        if($(".card").length>0) getCard();
        if($("#comment-area").length>0) getComment();
        $("#fue-comment").submit(function (event) {
            // Stop form from submitting normally
            event.preventDefault();
        
            var $form = $(this),
                con = $form.find("textarea[name='content']").val(),
                url = $form.attr("action");
        
            if (this.checkValidity() == false) {
                $form.classList.add("was-validated");
                event.stopPropagation();
            }
            // Send the data using post
            var posting = $.post(url, {
                content: con
            });
        
            posting.done(function (data) {
                if(data === 'OK') {
                    getComment();
                    $form.find("textarea[name='content']").val('');
                } else {
                    alert.html(data);
                    alert.show();
                }
            });
        });

    }, false);
}());

